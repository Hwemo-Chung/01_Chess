-- Pure run-state machine tying BoardRules/CombatRules/SpawnRules/Rng together.
-- No Roblox dependencies -- server/RunController.luau is the only thing that
-- touches Players/DataStore/RemoteEvents.
local BoardRules = require("./BoardRules")
local CombatRules = require("./CombatRules")
local SpawnRules = require("./SpawnRules")
local Rng = require("./Rng")

local RunState = {}
RunState.__index = RunState

local START_POSITION = { x = 3, z = 3 }

local function copyArray(source)
	return table.clone(source)
end

function RunState.new(roster: { string }, seed: number, config: any)
	assert(type(roster) == "table" and #roster > 0, "roster must be a non-empty array")
	return setmetatable({
		_config = config,
		_rng = Rng.new(seed),
		roster = copyArray(roster),
		activePiece = nil :: string?,
		activeHealth = 0,
		activeMaxHealth = 0,
		activePosition = { x = START_POSITION.x, z = START_POSITION.z },
		rerollsUsed = 0,
		invulnerable = false,
		level = 1,
		enemies = {},
	}, RunState)
end

local function drawFromRoster(self, excludePiece: string?)
	local candidates = {}
	for _, piece in ipairs(self.roster) do
		if piece ~= excludePiece then
			table.insert(candidates, piece)
		end
	end
	-- If excluding would empty the pool (e.g. a single-piece roster), fall
	-- back to drawing from the full roster instead of erroring.
	local pool = #candidates > 0 and candidates or self.roster
	local index = math.floor(self._rng:next() * #pool) + 1
	index = math.min(index, #pool)
	local drawn = pool[index]
	for position, piece in ipairs(self.roster) do
		if piece == drawn then
			table.remove(self.roster, position)
			break
		end
	end
	return drawn
end

local function spawnEnemiesForLevel(self)
	local config = self._config
	local count = SpawnRules.enemyCountForLevel(
		self.level,
		config.ENEMY_COUNT_CAP,
		config.ENEMY_START_COUNT,
		config.ENEMY_COUNT_PER_LEVEL
	)
	assert(SpawnRules.fitsOnBoard(count, config.BOARD_SIZE), "enemy count must fit on the board")
	local enemies = {}
	local occupied = { [self.activePosition.x .. "," .. self.activePosition.z] = true }
	while #enemies < count do
		local x = math.floor(self._rng:next() * config.BOARD_SIZE) + 1
		local z = math.floor(self._rng:next() * config.BOARD_SIZE) + 1
		local key = x .. "," .. z
		if not occupied[key] then
			occupied[key] = true
			table.insert(enemies, {
				x = x,
				z = z,
				health = config.ENEMY_BASE.maxHealth,
				maxHealth = config.ENEMY_BASE.maxHealth,
				attack = config.ENEMY_BASE.attack,
			})
		end
	end
	self.enemies = enemies
end

function RunState.assignRandomPiece(self)
	local piece = drawFromRoster(self, nil)
	local stats = self._config.PIECES[piece]
	self.activePiece = piece
	self.activeHealth = stats.maxHealth
	self.activeMaxHealth = stats.maxHealth
	self.rerollsUsed = 0
	self.invulnerable = true
	if self.activePosition == nil then
		self.activePosition = { x = START_POSITION.x, z = START_POSITION.z }
	end
	if #self.enemies == 0 then
		spawnEnemiesForLevel(self)
	end
end

function RunState.reroll(self): boolean
	if self.rerollsUsed >= self._config.REROLL_LIMIT then
		return false
	end
	self.rerollsUsed += 1
	local rejected = self.activePiece
	table.insert(self.roster, rejected)
	local piece = drawFromRoster(self, rejected)
	local stats = self._config.PIECES[piece]
	self.activePiece = piece
	self.activeHealth = stats.maxHealth
	self.activeMaxHealth = stats.maxHealth
	self.invulnerable = true
	return true
end

function RunState.legalMovesForActive(self)
	assert(self.activePiece ~= nil, "no active piece assigned")
	return BoardRules.legalMoves(
		self.activePiece,
		self.activePosition,
		self._config.BOARD_SIZE,
		self.enemies
	)
end

local function removeEnemyAt(enemies, position)
	for index, enemy in ipairs(enemies) do
		if enemy.x == position.x and enemy.z == position.z then
			table.remove(enemies, index)
			return
		end
	end
end

local function findEnemyAt(enemies, position)
	for _, enemy in ipairs(enemies) do
		if enemy.x == position.x and enemy.z == position.z then
			return enemy
		end
	end
	return nil
end

function RunState.applyPlayerMove(self, destination: BoardRules.Position)
	assert(self.activePiece ~= nil, "no active piece assigned")
	local legal = self:legalMovesForActive()
	local isLegal = false
	for _, move in ipairs(legal) do
		if move.x == destination.x and move.z == destination.z then
			isLegal = true
			break
		end
	end
	assert(isLegal, "destination is not a legal move for the active piece")

	local pieceStats = self._config.PIECES[self.activePiece]
	local result = {
		playerDamageDealt = 0,
		playerDamageTaken = 0,
		crit = false,
		pierced = false,
		enemyDied = false,
		levelCleared = false,
		runOver = false,
	}

	local target = findEnemyAt(self.enemies, destination)
	if target == nil then
		self.activePosition = { x = destination.x, z = destination.z }
		self.invulnerable = false
		return result
	end

	-- Origin BEFORE capture/land — pierce direction is origin → destination.
	local origin = { x = self.activePosition.x, z = self.activePosition.z }

	local attack = CombatRules.resolveAttack(
		{ attack = pieceStats.attack, critChance = pieceStats.critChance },
		self._config.CRIT_DAMAGE_MULTIPLIER,
		self._rng
	)
	result.crit = attack.crit
	result.playerDamageDealt = attack.damage
	target.health -= attack.damage
	result.enemyDied = target.health <= 0

	if not self.invulnerable then
		result.playerDamageTaken = target.attack
		self.activeHealth -= target.attack
	end
	self.invulnerable = false

	if result.enemyDied then
		removeEnemyAt(self.enemies, destination)
		self.activePosition = { x = destination.x, z = destination.z }

		local pierceTarget = CombatRules.resolvePierceTarget(
			self.activePiece,
			origin,
			destination,
			self.enemies,
			self._config.BOARD_SIZE
		)
		if pierceTarget ~= nil then
			local pierced = findEnemyAt(self.enemies, pierceTarget)
			if pierced ~= nil then
				pierced.health -= attack.damage
				result.pierced = true
				if pierced.health <= 0 then
					removeEnemyAt(self.enemies, pierceTarget)
				end
			end
		end
	end

	if self.activeHealth <= 0 then
		if #self.roster == 0 then
			result.runOver = true
		else
			self:assignRandomPiece()
			local safeSquare = SpawnRules.farthestSafeSquare(self._config.BOARD_SIZE, self.enemies)
			if safeSquare ~= nil then
				self.activePosition = safeSquare
			end
		end
	elseif #self.enemies == 0 then
		result.levelCleared = true
		self.level += 1
		spawnEnemiesForLevel(self)
	end

	return result
end

function RunState.snapshot(self)
	return {
		roster = copyArray(self.roster),
		activePiece = self.activePiece,
		activeHealth = self.activeHealth,
		activeMaxHealth = self.activeMaxHealth,
		activePosition = { x = self.activePosition.x, z = self.activePosition.z },
		invulnerable = self.invulnerable,
		level = self.level,
		enemies = copyArray(self.enemies),
	}
end

-- Test-only seams. Never called outside tests/server RunController in ways
-- that bypass legality -- these exist purely so combat-resolution tests
-- don't have to depend on RNG-driven spawn placement to set up scenarios.
function RunState._debugSetEnemies(self, enemies)
	self.enemies = enemies
end

function RunState._debugSetActiveHealth(self, health)
	self.activeHealth = health
end

function RunState._debugSetInvulnerable(self, invulnerable: boolean)
	self.invulnerable = invulnerable
end

return RunState

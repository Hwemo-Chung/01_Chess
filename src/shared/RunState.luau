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
		runOver = false,
		roundsPlayed = 0,
	}, RunState)
end

local function drawFromRoster(self, excludePiece: string?)
	local candidates = {}
	for _, piece in ipairs(self.roster) do
		if piece ~= excludePiece then
			table.insert(candidates, piece)
		end
	end
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

local function enemyCountCap(self): number
	local cap = self._config.ENEMY_COUNT_CAP
	-- Bishop active: half cap (PRD §6.4.2 — half board usable).
	if self.activePiece == "Bishop" then
		cap = math.max(1, math.floor(cap / 2))
	end
	return cap
end

local function spawnEnemiesForLevel(self)
	local config = self._config
	local cap = enemyCountCap(self)
	local count = SpawnRules.enemyCountForLevel(
		self.level,
		cap,
		config.ENEMY_START_COUNT,
		config.ENEMY_COUNT_PER_LEVEL
	)
	assert(SpawnRules.fitsOnBoard(count, config.BOARD_SIZE), "enemy count must fit on the board")

	local colorFilter: number? = nil
	if self.activePiece == "Bishop" then
		colorFilter = BoardRules.squareColor(self.activePosition)
	end

	local enemies = {}
	local occupied = { [self.activePosition.x .. "," .. self.activePosition.z] = true }
	local guard = 0
	while #enemies < count do
		guard += 1
		assert(guard < 5000, "spawn loop failed to place enemies")
		local x = math.floor(self._rng:next() * config.BOARD_SIZE) + 1
		local z = math.floor(self._rng:next() * config.BOARD_SIZE) + 1
		local colorOk = colorFilter == nil or (x + z) % 2 == colorFilter
		local key = x .. "," .. z
		if colorOk and not occupied[key] then
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

-- When switching onto Bishop, recolor-place existing enemies onto same color (PRD §6.4.2).
local function recolorEnemiesForBishop(self)
	if self.activePiece ~= "Bishop" then
		return
	end
	local color = BoardRules.squareColor(self.activePosition)
	local config = self._config
	local occupied = { [self.activePosition.x .. "," .. self.activePosition.z] = true }
	for _, enemy in ipairs(self.enemies) do
		if BoardRules.squareColor(enemy) == color then
			occupied[enemy.x .. "," .. enemy.z] = true
		end
	end
	for _, enemy in ipairs(self.enemies) do
		if BoardRules.squareColor(enemy) ~= color then
			local placed = false
			for _ = 1, 200 do
				local x = math.floor(self._rng:next() * config.BOARD_SIZE) + 1
				local z = math.floor(self._rng:next() * config.BOARD_SIZE) + 1
				if (x + z) % 2 == color then
					local key = x .. "," .. z
					if not occupied[key] then
						occupied[key] = true
						enemy.x = x
						enemy.z = z
						placed = true
						break
					end
				end
			end
			assert(placed, "failed to recolor enemy for Bishop")
		end
	end
end

function RunState.assignRandomPiece(self)
	local piece = drawFromRoster(self, nil)
	local stats = self._config.PIECES[piece]
	assert(stats ~= nil, "unknown piece in roster: " .. tostring(piece))
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
	else
		recolorEnemiesForBishop(self)
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
	recolorEnemiesForBishop(self)
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
	assert(not self.runOver, "run is over")
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

	self.roundsPlayed += 1

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

	local origin = { x = self.activePosition.x, z = self.activePosition.z }
	local critChance = CombatRules.critChanceForAttack(
		self.activePiece,
		pieceStats,
		origin,
		destination,
		self._config
	)

	local attack = CombatRules.resolveAttack(
		{ attack = pieceStats.attack, critChance = critChance },
		self._config.CRIT_DAMAGE_MULTIPLIER,
		self._rng
	)
	result.crit = attack.crit
	result.playerDamageDealt = attack.damage
	target.health -= attack.damage
	result.enemyDied = target.health <= 0

	if not self.invulnerable then
		local mult = pieceStats.incomingDamageMultiplier or 1
		result.playerDamageTaken = target.attack * mult
		self.activeHealth -= result.playerDamageTaken
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
			self.runOver = true
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

local function copyEnemies(enemies)
	local result = {}
	for index, enemy in ipairs(enemies) do
		result[index] = {
			x = enemy.x,
			z = enemy.z,
			health = enemy.health,
			maxHealth = enemy.maxHealth,
			attack = enemy.attack,
		}
	end
	return result
end

local function copyPositions(positions)
	local result = {}
	for index, position in ipairs(positions) do
		result[index] = { x = position.x, z = position.z }
	end
	return result
end

function RunState.previewsForActive(self)
	if self.activePiece == nil or self.runOver then
		return {}
	end
	local pieceStats = self._config.PIECES[self.activePiece]
	local origin = self.activePosition
	local previews = {}
	for _, move in ipairs(self:legalMovesForActive()) do
		local enemy = findEnemyAt(self.enemies, move)
		local preview = CombatRules.previewDestination(
			self.activePiece,
			pieceStats,
			origin,
			move,
			enemy,
			self.invulnerable,
			self.activeHealth,
			self._config
		)
		previews[move.x .. "," .. move.z] = preview
	end
	return previews
end

function RunState.snapshot(self)
	local legalMoves = {}
	local previews = {}
	if self.activePiece ~= nil and not self.runOver then
		legalMoves = copyPositions(self:legalMovesForActive())
		previews = self:previewsForActive()
	end
	return {
		roster = copyArray(self.roster),
		activePiece = self.activePiece,
		activeHealth = self.activeHealth,
		activeMaxHealth = self.activeMaxHealth,
		activePosition = { x = self.activePosition.x, z = self.activePosition.z },
		invulnerable = self.invulnerable,
		level = self.level,
		enemies = copyEnemies(self.enemies),
		legalMoves = legalMoves,
		previews = previews,
		rerollsRemaining = math.max(0, self._config.REROLL_LIMIT - self.rerollsUsed),
		runOver = self.runOver,
		roundsPlayed = self.roundsPlayed,
		phase = if self.runOver then "GameOver" else "Turn",
	}
end

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

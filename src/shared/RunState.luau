-- Pure run-state machine: turn combat, tier ladder, King-clear victory,
-- permanent upgrades, transcendence enemy scaling.
local BoardRules = require("./BoardRules")
local CombatRules = require("./CombatRules")
local SpawnRules = require("./SpawnRules")
local ProfileRules = require("./ProfileRules")
local Rng = require("./Rng")

local RunState = {}
RunState.__index = RunState

local START_POSITION = { x = 3, z = 3 }

local function copyArray(source)
	return table.clone(source)
end

function RunState.new(roster: { string }, seed: number, config: any, options: any?)
	assert(type(roster) == "table" and #roster > 0, "roster must be a non-empty array")
	options = options or {}
	local upgrades = options.upgrades or {}
	local transcendenceLevel = options.transcendenceLevel or config.DEFAULT_TRANSCENDENCE or 1
	if transcendenceLevel < 1 then
		transcendenceLevel = 1
	end
	return setmetatable({
		_config = config,
		_rng = Rng.new(seed),
		_upgrades = upgrades,
		transcendenceLevel = transcendenceLevel,
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
		victory = false,
		roundsPlayed = 0,
		currentTier = "Pawn",
	}, RunState)
end

local function activeStats(self)
	local base = self._config.PIECES[self.activePiece]
	return ProfileRules.effectivePieceStats(base, self._upgrades, self._config)
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
	if self.activePiece == "Bishop" then
		cap = math.max(1, math.floor(cap / 2))
	end
	return cap
end

local function scaledEnemyStats(self, pieceType: string, isBoss: boolean)
	local base = self._config.PIECES[pieceType] or self._config.ENEMY_BASE
	local mult = self.transcendenceLevel
	local hp = base.maxHealth * mult
	local attack = base.attack * mult
	if isBoss then
		hp *= self._config.BOSS_HEALTH_MULTIPLIER or 3
	end
	return {
		maxHealth = math.max(1, math.floor(hp + 0.5)),
		attack = math.max(1, math.floor(attack + 0.5)),
		critChance = base.critChance or 0.15,
		incomingDamageMultiplier = base.incomingDamageMultiplier or 1,
		critFromDistance = base.critFromDistance,
	}
end

local function makeEnemy(self, x: number, z: number, pieceType: string, isBoss: boolean)
	local stats = scaledEnemyStats(self, pieceType, isBoss)
	return {
		x = x,
		z = z,
		health = stats.maxHealth,
		maxHealth = stats.maxHealth,
		attack = stats.attack,
		pieceType = pieceType,
		isBoss = isBoss == true,
		critChance = stats.critChance,
		incomingDamageMultiplier = stats.incomingDamageMultiplier,
		critFromDistance = stats.critFromDistance,
	}
end

local function pickSpawnCell(self, occupied, colorFilter: number?): (number?, number?)
	local config = self._config
	for _ = 1, 400 do
		local x = math.floor(self._rng:next() * config.BOARD_SIZE) + 1
		local z = math.floor(self._rng:next() * config.BOARD_SIZE) + 1
		local colorOk = colorFilter == nil or (x + z) % 2 == colorFilter
		local key = x .. "," .. z
		if colorOk and not occupied[key] then
			return x, z
		end
	end
	return nil, nil
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

	local tier, isBossStage =
		SpawnRules.tierForLevel(self.level, config.ENEMY_COUNT_CAP, config.ENEMY_TIER_ORDER)
	self.currentTier = tier

	local colorFilter: number? = nil
	if self.activePiece == "Bishop" then
		colorFilter = BoardRules.squareColor(self.activePosition)
	end

	local enemies = {}
	local occupied = { [self.activePosition.x .. "," .. self.activePosition.z] = true }

	if isBossStage then
		-- King boss + lower-tier minions filling the rest of the cap count.
		local bx, bz = pickSpawnCell(self, occupied, colorFilter)
		assert(bx ~= nil, "failed to place King boss")
		occupied[bx .. "," .. bz] = true
		table.insert(enemies, makeEnemy(self, bx :: number, bz :: number, "King", true))
		local minionType = "Queen"
		local order = config.ENEMY_TIER_ORDER
		for i, name in ipairs(order) do
			if name == "King" and i > 1 then
				minionType = order[i - 1]
				break
			end
		end
		while #enemies < count do
			local x, z = pickSpawnCell(self, occupied, colorFilter)
			assert(x ~= nil, "failed to place minion")
			occupied[x .. "," .. z] = true
			table.insert(enemies, makeEnemy(self, x :: number, z :: number, minionType, false))
		end
	else
		while #enemies < count do
			local x, z = pickSpawnCell(self, occupied, colorFilter)
			assert(x ~= nil, "failed to place enemy")
			occupied[x .. "," .. z] = true
			table.insert(enemies, makeEnemy(self, x :: number, z :: number, tier, false))
		end
	end

	self.enemies = enemies
end

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
	local stats =
		ProfileRules.effectivePieceStats(self._config.PIECES[piece], self._upgrades, self._config)
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
	local stats =
		ProfileRules.effectivePieceStats(self._config.PIECES[piece], self._upgrades, self._config)
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
	assert(not self.runOver and not self.victory, "run is finished")
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

	local pieceStats = activeStats(self)
	local result = {
		playerDamageDealt = 0,
		playerDamageTaken = 0,
		crit = false,
		pierced = false,
		enemyDied = false,
		levelCleared = false,
		runOver = false,
		victory = false,
		bossKilled = false,
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

	-- Enemy incoming mult (enemy King takes half, enemy Queen takes 1.5x).
	local damageToEnemy = attack.damage * (target.incomingDamageMultiplier or 1)
	result.playerDamageDealt = damageToEnemy
	target.health -= damageToEnemy
	result.enemyDied = target.health <= 0

	local killedBoss = result.enemyDied and target.isBoss == true

	-- Mutual-KO: if King boss dies, victory is forced before lethal counter (PRD §6.2).
	local counterDamage = 0
	if not self.invulnerable then
		counterDamage = target.attack * (pieceStats.incomingDamageMultiplier or 1)
	end
	result.playerDamageTaken = counterDamage

	if killedBoss then
		result.bossKilled = true
		result.victory = true
		result.enemyDied = true
		self.victory = true
		self.runOver = true
		removeEnemyAt(self.enemies, destination)
		self.activePosition = { x = destination.x, z = destination.z }
		self.invulnerable = false
		-- Counter is recorded for VFX only; does not flip victory.
		return result
	end

	if not self.invulnerable then
		self.activeHealth -= counterDamage
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
				local pierceDamage = attack.damage * (pierced.incomingDamageMultiplier or 1)
				pierced.health -= pierceDamage
				result.pierced = true
				if pierced.health <= 0 then
					if pierced.isBoss then
						result.bossKilled = true
						result.victory = true
						self.victory = true
						self.runOver = true
						removeEnemyAt(self.enemies, pierceTarget)
						return result
					end
					removeEnemyAt(self.enemies, pierceTarget)
				end
			end
		end
	end

	-- Level-clear before life-loss handling: killing the last enemy must advance
	-- the stage even if the counterattack also drops the player (otherwise
	-- assignRandomPiece respawns the *same* level forever).
	local boardCleared = #self.enemies == 0
	if boardCleared then
		result.levelCleared = true
		self.level += 1
	end

	if self.activeHealth <= 0 then
		if #self.roster == 0 then
			result.runOver = true
			self.runOver = true
			-- Don't leave an empty board mid-ladder after a dead-end mutual clear.
			if boardCleared and not self.victory then
				spawnEnemiesForLevel(self)
			end
		else
			self:assignRandomPiece()
			-- assignRandomPiece spawns if enemies empty (new level after clear).
			local safeSquare = SpawnRules.farthestSafeSquare(self._config.BOARD_SIZE, self.enemies)
			if safeSquare ~= nil then
				self.activePosition = safeSquare
			end
		end
	elseif boardCleared then
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
			pieceType = enemy.pieceType,
			isBoss = enemy.isBoss,
			incomingDamageMultiplier = enemy.incomingDamageMultiplier,
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
	if self.activePiece == nil or self.runOver or self.victory then
		return {}
	end
	local pieceStats = activeStats(self)
	local origin = self.activePosition
	local previews = {}
	for _, move in ipairs(self:legalMovesForActive()) do
		local enemy = findEnemyAt(self.enemies, move)
		-- Preview uses enemy attack as-is; damage-to-enemy mult applied in summary via health.
		local previewEnemy = enemy
		if enemy ~= nil then
			previewEnemy = table.clone(enemy)
			-- Present effective HP from player damage perspective by scaling display health.
			-- Keep real health; previewDestination compares base damage to health.
			-- Adjust: expose health / incomingMult equivalent so killChance is accurate.
			local mult = enemy.incomingDamageMultiplier or 1
			if mult > 0 and mult ~= 1 then
				previewEnemy = table.clone(enemy)
				previewEnemy.health = enemy.health / mult
			end
		end
		local preview = CombatRules.previewDestination(
			self.activePiece,
			pieceStats,
			origin,
			move,
			previewEnemy,
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
	local finished = self.runOver or self.victory
	if self.activePiece ~= nil and not finished then
		legalMoves = copyPositions(self:legalMovesForActive())
		previews = self:previewsForActive()
	end
	local phase = "Turn"
	if self.victory then
		phase = "Victory"
	elseif self.runOver then
		phase = "GameOver"
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
		runOver = self.runOver or self.victory,
		victory = self.victory,
		roundsPlayed = self.roundsPlayed,
		currentTier = self.currentTier,
		transcendenceLevel = self.transcendenceLevel,
		phase = phase,
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

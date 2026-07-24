-- Pure spawn-capacity and safe-square invariants. No Roblox dependencies.
local BoardRules = require("./BoardRules")

local SpawnRules = {}

function SpawnRules.enemyCountForLevel(
	level: number,
	cap: number,
	startCount: number,
	perLevel: number
): number
	assert(level >= 1, "level must be at least 1")
	local count = startCount + (level - 1) * perLevel
	return math.min(count, cap)
end

-- Returns (tierPieceType, isKingBossStage).
-- Levels 1..cap: count ramps, tier stays Pawn.
-- Levels cap+1..: count fixed at cap, tier climbs Knight→…→King.
function SpawnRules.tierForLevel(
	level: number,
	cap: number,
	tierOrder: { string }
): (string, boolean)
	assert(level >= 1, "level must be at least 1")
	assert(type(tierOrder) == "table" and #tierOrder > 0, "tierOrder required")
	if level <= cap then
		return tierOrder[1], false
	end
	-- level = cap+1 → index 2 (Knight when order starts with Pawn)
	local index = math.min(level - cap + 1, #tierOrder)
	local tier = tierOrder[index]
	return tier, tier == "King"
end

-- 36 tiles total, minus 1 for the player, is the hard ceiling this asserts.
-- Proven necessary in the PRD (§6.2) via the pigeonhole principle: an
-- uncapped count against a fixed board always eventually exceeds it.
function SpawnRules.fitsOnBoard(enemyCount: number, boardSize: number): boolean
	return enemyCount <= (boardSize * boardSize) - 1
end

local function isAdjacentOrEqual(a: BoardRules.Position, b: BoardRules.Position): boolean
	return math.abs(a.x - b.x) <= 1 and math.abs(a.z - b.z) <= 1
end

-- A "safe" square is one that is neither occupied by an enemy nor adjacent
-- to one -- the invariant safe-respawn (farthest teleport) and zugzwang
-- mitigation (guaranteed non-adjacent legal move) both depend on at least
-- one such square existing (PRD §6.1/§6.2).
function SpawnRules.hasSafeSquare(
	boardSize: number,
	enemyPositions: { BoardRules.Position },
	excludePosition: BoardRules.Position?
): boolean
	for x = 1, boardSize do
		for z = 1, boardSize do
			local candidate = { x = x, z = z }
			if
				excludePosition == nil
				or not (candidate.x == excludePosition.x and candidate.z == excludePosition.z)
			then
				local safe = true
				for _, enemy in ipairs(enemyPositions) do
					if isAdjacentOrEqual(candidate, enemy) then
						safe = false
						break
					end
				end
				if safe then
					return true
				end
			end
		end
	end
	return false
end

function SpawnRules.farthestSafeSquare(
	boardSize: number,
	enemyPositions: { BoardRules.Position }
): BoardRules.Position?
	local best: BoardRules.Position? = nil
	local bestDistance = -1
	for x = 1, boardSize do
		for z = 1, boardSize do
			local candidate = { x = x, z = z }
			local safe = true
			local nearestEnemyDistance = math.huge
			for _, enemy in ipairs(enemyPositions) do
				if isAdjacentOrEqual(candidate, enemy) then
					safe = false
					break
				end
				-- Euclidean-squared: uniquely prefers the opposite corner over
				-- Chebyshev-ties like (1,6)/(6,1) when the only enemy is at (1,1).
				local dx = candidate.x - enemy.x
				local dz = candidate.z - enemy.z
				local distance = dx * dx + dz * dz
				if distance < nearestEnemyDistance then
					nearestEnemyDistance = distance
				end
			end
			if safe and nearestEnemyDistance > bestDistance then
				bestDistance = nearestEnemyDistance
				best = candidate
			end
		end
	end
	return best
end

return SpawnRules

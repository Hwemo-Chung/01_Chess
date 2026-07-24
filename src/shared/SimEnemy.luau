-- Pure enemy turn for offline simulation (mirrors server EnemyAI policy).
local BoardRules = require("./BoardRules")

local SimEnemy = {}

local function manhattan(a, b): number
	return math.abs(a.x - b.x) + math.abs(a.z - b.z)
end

local function isKnightRing(playerPos, cell): boolean
	local dx = math.abs(playerPos.x - cell.x)
	local dz = math.abs(playerPos.z - cell.z)
	return (dx == 1 and dz == 2) or (dx == 2 and dz == 1)
end

local function playerCanCapture(
	playerPieceType,
	playerPosition,
	enemyPos,
	boardSize,
	blockers
): boolean
	if playerPieceType == nil then
		return true
	end
	local legal = BoardRules.legalMoves(playerPieceType, playerPosition, boardSize, blockers)
	for _, move in ipairs(legal) do
		if move.x == enemyPos.x and move.z == enemyPos.z then
			return true
		end
	end
	return false
end

function SimEnemy.applyTurn(state)
	local enemies = state.enemies
	local playerPosition = state.activePosition
	local boardSize = state._config.BOARD_SIZE
	local playerPieceType = state.activePiece

	local reserved = {}
	for _, enemy in ipairs(enemies) do
		reserved[enemy.x .. "," .. enemy.z] = true
	end
	reserved[playerPosition.x .. "," .. playerPosition.z] = true

	local allBlockersForPlayer = {}
	for _, enemy in ipairs(enemies) do
		table.insert(allBlockersForPlayer, { x = enemy.x, z = enemy.z })
	end

	for index, enemy in ipairs(enemies) do
		local pieceType = enemy.pieceType or "Pawn"
		local blockers = {}
		for j, other in ipairs(enemies) do
			if j ~= index then
				table.insert(blockers, { x = other.x, z = other.z })
			end
		end
		table.insert(blockers, { x = playerPosition.x, z = playerPosition.z })

		local legal =
			BoardRules.legalMoves(pieceType, { x = enemy.x, z = enemy.z }, boardSize, blockers)
		local destination = { x = enemy.x, z = enemy.z }
		local bestScore = -1e18

		local dx = math.abs(playerPosition.x - enemy.x)
		local dz = math.abs(playerPosition.z - enemy.z)
		local adjacent = dx <= 1 and dz <= 1
		local capturable = playerCanCapture(
			playerPieceType,
			playerPosition,
			{ x = enemy.x, z = enemy.z },
			boardSize,
			allBlockersForPlayer
		)
		local onKnightRing = playerPieceType == "Knight"
			and isKnightRing(playerPosition, { x = enemy.x, z = enemy.z })
		local freeze = (adjacent and capturable) or onKnightRing

		if not freeze then
			local found = false
			for _, candidate in ipairs(legal) do
				local key = candidate.x .. "," .. candidate.z
				if not reserved[key] then
					local cdx = math.abs(playerPosition.x - candidate.x)
					local cdz = math.abs(playerPosition.z - candidate.z)
					local knightAdj = playerPieceType == "Knight" and cdx <= 1 and cdz <= 1
					local dist = manhattan(candidate, playerPosition)
					local score = -dist * 10
					if playerPieceType == "Knight" and isKnightRing(playerPosition, candidate) then
						score += 80
					end
					if knightAdj then
						score -= 100
					end
					if score > bestScore then
						bestScore = score
						destination = { x = candidate.x, z = candidate.z }
						found = true
					end
				end
			end
			if
				playerPieceType == "Knight"
				and math.abs(playerPosition.x - destination.x) <= 1
				and math.abs(playerPosition.z - destination.z) <= 1
			then
				local farScore = -1
				for _, candidate in ipairs(legal) do
					local key = candidate.x .. "," .. candidate.z
					if not reserved[key] then
						local dist = manhattan(candidate, playerPosition)
						if dist > farScore then
							farScore = dist
							destination = { x = candidate.x, z = candidate.z }
							found = true
						end
					end
				end
			end
			if not found then
				destination = { x = enemy.x, z = enemy.z }
			end
		end

		reserved[enemy.x .. "," .. enemy.z] = nil
		reserved[destination.x .. "," .. destination.z] = true
		enemy.x = destination.x
		enemy.z = destination.z
	end
end

return SimEnemy

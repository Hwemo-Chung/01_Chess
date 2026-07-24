-- Pure enemy turn for offline simulation (mirrors server EnemyAI policy).
local BoardRules = require("./BoardRules")

local SimEnemy = {}

local function manhattan(a, b): number
	return math.abs(a.x - b.x) + math.abs(a.z - b.z)
end

function SimEnemy.applyTurn(state)
	local enemies = state.enemies
	local playerPosition = state.activePosition
	local boardSize = state._config.BOARD_SIZE

	local reserved = {}
	for _, enemy in ipairs(enemies) do
		reserved[enemy.x .. "," .. enemy.z] = true
	end
	reserved[playerPosition.x .. "," .. playerPosition.z] = true

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
		local bestDist = manhattan(destination, playerPosition)

		local dx = math.abs(playerPosition.x - enemy.x)
		local dz = math.abs(playerPosition.z - enemy.z)
		if not (dx <= 1 and dz <= 1) then
			for _, candidate in ipairs(legal) do
				local key = candidate.x .. "," .. candidate.z
				if not reserved[key] then
					local dist = manhattan(candidate, playerPosition)
					if dist < bestDist then
						bestDist = dist
						destination = { x = candidate.x, z = candidate.z }
					end
				end
			end
		end

		reserved[enemy.x .. "," .. enemy.z] = nil
		reserved[destination.x .. "," .. destination.z] = true
		enemy.x = destination.x
		enemy.z = destination.z
	end
end

return SimEnemy

-- Simple greedy chase: each enemy steps 1 square toward the player along
-- whichever axis has the larger gap (ponytail: no pathfinding, no A* --
-- MVP enemies are undifferentiated Pawn-like movers per PRD §11 scope cut).
local EnemyAI = {}

local function clampStep(delta: number): number
	if delta > 0 then
		return 1
	elseif delta < 0 then
		return -1
	end
	return 0
end

function EnemyAI.planMoves(enemies, playerPosition, boardSize: number)
	local reserved = {}
	for _, enemy in ipairs(enemies) do
		reserved[enemy.x .. "," .. enemy.z] = true
	end

	local moves = {}
	for _, enemy in ipairs(enemies) do
		local dx = playerPosition.x - enemy.x
		local dz = playerPosition.z - enemy.z
		local isAdjacent = math.abs(dx) <= 1 and math.abs(dz) <= 1
		local destination = { x = enemy.x, z = enemy.z }

		if not isAdjacent then
			local stepX, stepZ = 0, 0
			if math.abs(dx) >= math.abs(dz) then
				stepX = clampStep(dx)
			else
				stepZ = clampStep(dz)
			end
			local candidate = { x = enemy.x + stepX, z = enemy.z + stepZ }
			local inBounds = candidate.x >= 1
				and candidate.x <= boardSize
				and candidate.z >= 1
				and candidate.z <= boardSize
			local key = candidate.x .. "," .. candidate.z
			if inBounds and not reserved[key] then
				destination = candidate
			end
		end

		reserved[enemy.x .. "," .. enemy.z] = nil
		reserved[destination.x .. "," .. destination.z] = true
		table.insert(moves, destination)
	end
	return moves
end

return EnemyAI

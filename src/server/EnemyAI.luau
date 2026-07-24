-- Greedy chase using each enemy's piece legal moves (PRD §6.2 — shared movesets).
local BoardRules
do
	local ok, mod = pcall(function()
		return require("../shared/BoardRules")
	end)
	if ok then
		BoardRules = mod
	else
		local Shared =
			game:GetService("ReplicatedStorage"):WaitForChild("Chess"):WaitForChild("Shared")
		BoardRules = require(Shared:WaitForChild("BoardRules"))
	end
end

local EnemyAI = {}

local function distance(a, b): number
	return math.abs(a.x - b.x) + math.abs(a.z - b.z)
end

function EnemyAI.planMoves(enemies, playerPosition, boardSize: number)
	local reserved = {}
	for _, enemy in ipairs(enemies) do
		reserved[enemy.x .. "," .. enemy.z] = true
	end
	reserved[playerPosition.x .. "," .. playerPosition.z] = true

	local moves = {}
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
		local bestDist = distance(destination, playerPosition)

		local dx = math.abs(playerPosition.x - enemy.x)
		local dz = math.abs(playerPosition.z - enemy.z)
		if not (dx <= 1 and dz <= 1) then
			for _, candidate in ipairs(legal) do
				local key = candidate.x .. "," .. candidate.z
				if not reserved[key] then
					local dist = distance(candidate, playerPosition)
					if dist < bestDist then
						bestDist = dist
						destination = { x = candidate.x, z = candidate.z }
					end
				end
			end
		end

		reserved[enemy.x .. "," .. enemy.z] = nil
		reserved[destination.x .. "," .. destination.z] = true
		table.insert(moves, destination)
	end
	return moves
end

return EnemyAI

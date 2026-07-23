-- Pure legal-move generation. No Roblox dependencies.
local BoardRules = {}

export type Position = { x: number, z: number }

local ORTHOGONAL_DIRECTIONS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
local KNIGHT_OFFSETS = {
	{ 1, 2 },
	{ 2, 1 },
	{ -1, 2 },
	{ -2, 1 },
	{ 1, -2 },
	{ 2, -1 },
	{ -1, -2 },
	{ -2, -1 },
}

local function inBounds(x: number, z: number, boardSize: number): boolean
	return x >= 1 and x <= boardSize and z >= 1 and z <= boardSize
end

local function occupancySet(enemyPositions: { Position }): { [string]: boolean }
	local occupied = {}
	for _, enemy in ipairs(enemyPositions) do
		occupied[enemy.x .. "," .. enemy.z] = true
	end
	return occupied
end

function BoardRules.enemyAt(position: Position, enemyPositions: { Position }): boolean
	for _, enemy in ipairs(enemyPositions) do
		if enemy.x == position.x and enemy.z == position.z then
			return true
		end
	end
	return false
end

function BoardRules.legalMoves(
	pieceType: string,
	position: Position,
	boardSize: number,
	enemyPositions: { Position }
): { Position }
	assert(
		type(position) == "table" and type(position.x) == "number" and type(position.z) == "number",
		"position must be {x, z}"
	)
	local moves: { Position } = {}

	if pieceType == "Pawn" then
		for _, direction in ipairs(ORTHOGONAL_DIRECTIONS) do
			local x, z = position.x + direction[1], position.z + direction[2]
			if inBounds(x, z, boardSize) then
				table.insert(moves, { x = x, z = z })
			end
		end
	elseif pieceType == "Knight" then
		for _, offset in ipairs(KNIGHT_OFFSETS) do
			local x, z = position.x + offset[1], position.z + offset[2]
			if inBounds(x, z, boardSize) then
				table.insert(moves, { x = x, z = z })
			end
		end
	elseif pieceType == "Rook" then
		local occupied = occupancySet(enemyPositions)
		for _, direction in ipairs(ORTHOGONAL_DIRECTIONS) do
			local x, z = position.x, position.z
			while true do
				x += direction[1]
				z += direction[2]
				if not inBounds(x, z, boardSize) then
					break
				end
				table.insert(moves, { x = x, z = z })
				if occupied[x .. "," .. z] then
					-- BLOCKED: this square (the enemy) is a legal capture
					-- target, but nothing further along this line is.
					break
				end
			end
		end
	else
		error("unknown MVP piece type: " .. tostring(pieceType))
	end

	return moves
end

return BoardRules

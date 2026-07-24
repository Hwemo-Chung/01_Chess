-- Pure legal-move generation. No Roblox dependencies.
local BoardRules = {}

export type Position = { x: number, z: number }

local ORTHOGONAL_DIRECTIONS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
local DIAGONAL_DIRECTIONS = { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }
local KING_OFFSETS = {
	{ 1, 0 },
	{ -1, 0 },
	{ 0, 1 },
	{ 0, -1 },
	{ 1, 1 },
	{ 1, -1 },
	{ -1, 1 },
	{ -1, -1 },
}
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

local function collectSliding(
	position: Position,
	boardSize: number,
	directions,
	occupied
): { Position }
	local moves = {}
	for _, direction in ipairs(directions) do
		local x, z = position.x, position.z
		while true do
			x += direction[1]
			z += direction[2]
			if not inBounds(x, z, boardSize) then
				break
			end
			table.insert(moves, { x = x, z = z })
			if occupied[x .. "," .. z] then
				break
			end
		end
	end
	return moves
end

function BoardRules.enemyAt(position: Position, enemyPositions: { Position }): boolean
	for _, enemy in ipairs(enemyPositions) do
		if enemy.x == position.x and enemy.z == position.z then
			return true
		end
	end
	return false
end

-- Chess-square color parity (Bishop color-blindness): (x+z) even vs odd.
function BoardRules.squareColor(position: Position): number
	return (position.x + position.z) % 2
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
	elseif pieceType == "King" then
		for _, offset in ipairs(KING_OFFSETS) do
			local x, z = position.x + offset[1], position.z + offset[2]
			if inBounds(x, z, boardSize) then
				table.insert(moves, { x = x, z = z })
			end
		end
	elseif pieceType == "Rook" then
		local occupied = occupancySet(enemyPositions)
		moves = collectSliding(position, boardSize, ORTHOGONAL_DIRECTIONS, occupied)
	elseif pieceType == "Bishop" then
		local occupied = occupancySet(enemyPositions)
		moves = collectSliding(position, boardSize, DIAGONAL_DIRECTIONS, occupied)
	elseif pieceType == "Queen" then
		local occupied = occupancySet(enemyPositions)
		local ortho = collectSliding(position, boardSize, ORTHOGONAL_DIRECTIONS, occupied)
		local diag = collectSliding(position, boardSize, DIAGONAL_DIRECTIONS, occupied)
		for _, move in ipairs(ortho) do
			table.insert(moves, move)
		end
		for _, move in ipairs(diag) do
			table.insert(moves, move)
		end
	else
		error("unknown piece type: " .. tostring(pieceType))
	end

	return moves
end

return BoardRules

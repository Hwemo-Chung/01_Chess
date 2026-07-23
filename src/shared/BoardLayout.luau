-- Pure board ↔ world coordinate helpers. Shared by client BoardView and any
-- server-side visual helpers. No Roblox Instance dependencies.
local Config = require("./Config")

local BoardLayout = {}

BoardLayout.TILE_SIZE = 6
BoardLayout.BOARD_Y = 0.5
BoardLayout.PIECE_Y = 3

local function halfExtent(): number
	return (Config.BOARD_SIZE * BoardLayout.TILE_SIZE) / 2
end

function BoardLayout.gridToWorld(x: number, z: number): (number, number, number)
	local half = halfExtent()
	local worldX = (x - 0.5) * BoardLayout.TILE_SIZE - half
	local worldZ = (z - 0.5) * BoardLayout.TILE_SIZE - half
	return worldX, BoardLayout.BOARD_Y, worldZ
end

function BoardLayout.gridToPieceWorld(x: number, z: number): (number, number, number)
	local worldX, _, worldZ = BoardLayout.gridToWorld(x, z)
	return worldX, BoardLayout.PIECE_Y, worldZ
end

function BoardLayout.worldToGrid(worldX: number, worldZ: number): (number?, number?)
	local half = halfExtent()
	local x = math.floor((worldX + half) / BoardLayout.TILE_SIZE) + 1
	local z = math.floor((worldZ + half) / BoardLayout.TILE_SIZE) + 1
	if x < 1 or x > Config.BOARD_SIZE or z < 1 or z > Config.BOARD_SIZE then
		return nil, nil
	end
	return x, z
end

function BoardLayout.boardCenter(): (number, number, number)
	return 0, BoardLayout.BOARD_Y, 0
end

function BoardLayout.boardExtent(): number
	return Config.BOARD_SIZE * BoardLayout.TILE_SIZE
end

return BoardLayout

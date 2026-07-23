-- tests/BoardLayout.spec.luau
local BoardLayout = require("../src/shared/BoardLayout")
local Config = require("../src/shared/Config")

local cases = {}
local function case(name, body)
	table.insert(cases, { name = name, body = body })
end

case("gridToWorld / round-trips through worldToGrid for every cell", function()
	for x = 1, Config.BOARD_SIZE do
		for z = 1, Config.BOARD_SIZE do
			local wx, _, wz = BoardLayout.gridToWorld(x, z)
			local gx, gz = BoardLayout.worldToGrid(wx, wz)
			assert(
				gx == x and gz == z,
				string.format(
					"round-trip failed for (%d,%d) -> (%s,%s)",
					x,
					z,
					tostring(gx),
					tostring(gz)
				)
			)
		end
	end
end)

case("worldToGrid / returns nil outside the board", function()
	local gx, gz = BoardLayout.worldToGrid(999, 999)
	assert(gx == nil and gz == nil, "out-of-board coordinates must be nil")
end)

case("boardExtent / matches BOARD_SIZE * TILE_SIZE", function()
	assert(
		BoardLayout.boardExtent() == Config.BOARD_SIZE * BoardLayout.TILE_SIZE,
		"extent mismatch"
	)
end)

return function()
	for _, entry in ipairs(cases) do
		local ok, err = pcall(entry.body)
		assert(ok, entry.name .. " FAILED: " .. tostring(err))
	end
	print(string.format("BoardLayout: PASS (%d cases)", #cases))
	return #cases
end

-- tests/SpawnRules.spec.luau
local SpawnRules = require("../src/shared/SpawnRules")

local cases = {}
local function case(name, body)
	table.insert(cases, { name = name, body = body })
end

case("enemyCountForLevel / ramps up then plateaus at the cap", function()
	assert(SpawnRules.enemyCountForLevel(1, 12, 1, 1) == 1, "level 1")
	assert(SpawnRules.enemyCountForLevel(2, 12, 1, 1) == 2, "level 2")
	assert(
		SpawnRules.enemyCountForLevel(20, 12, 1, 1) == 12,
		"level 20 must plateau at the cap, not keep climbing"
	)
end)

case("fitsOnBoard / rejects a level whose enemy count exceeds usable tiles", function()
	-- 6x6 = 36 tiles, 1 reserved for the player = 35 usable.
	assert(SpawnRules.fitsOnBoard(35, 6), "35 enemies must fit on a 6x6 board")
	assert(not SpawnRules.fitsOnBoard(36, 6), "36 enemies must NOT fit (no room for the player)")
end)

case("hasSafeSquare / true on an empty board", function()
	assert(SpawnRules.hasSafeSquare(6, {}, nil), "an empty board always has a safe square")
end)

case("hasSafeSquare / false when every square is occupied or adjacent to an enemy", function()
	-- Pack a 3x3 board (9 tiles) with kings-graph-dominating occupants so that
	-- every square is either occupied or 8-adjacent to one -- corners of a
	-- 3x3 at (1,1) and (3,3) do NOT dominate the center-edge tiles, so use a
	-- denser, unambiguous case: occupy every single tile on a 2x2 board.
	local enemies = { { x = 1, z = 1 }, { x = 1, z = 2 }, { x = 2, z = 1 }, { x = 2, z = 2 } }
	assert(
		not SpawnRules.hasSafeSquare(2, enemies, nil),
		"fully occupied 2x2 board has no safe square"
	)
end)

case(
	"farthestSafeSquare / picks the square with zero adjacent enemies farthest from them",
	function()
		local enemies = { { x = 1, z = 1 } }
		local target = SpawnRules.farthestSafeSquare(6, enemies)
		assert(target ~= nil, "expected a safe square")
		-- The farthest corner from (1,1) on a 6x6 board is (6,6).
		assert(
			target.x == 6 and target.z == 6,
			"expected the opposite corner, got (" .. target.x .. "," .. target.z .. ")"
		)
	end
)

case("farthestSafeSquare / nil when the board has no safe square at all", function()
	local enemies = { { x = 1, z = 1 }, { x = 1, z = 2 }, { x = 2, z = 1 }, { x = 2, z = 2 } }
	local target = SpawnRules.farthestSafeSquare(2, enemies)
	assert(target == nil, "expected nil when no safe square exists")
end)

return function()
	for _, entry in ipairs(cases) do
		local ok, err = pcall(entry.body)
		assert(ok, entry.name .. " FAILED: " .. tostring(err))
	end
	print(string.format("SpawnRules: PASS (%d cases)", #cases))
	return #cases
end

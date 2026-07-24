-- tests/EnemyAI.spec.luau
local EnemyAI = require("../src/server/EnemyAI")

local cases = {}
local function case(name, body)
	table.insert(cases, { name = name, body = body })
end

case("planMoves / steps one square closer to the player", function()
	local enemies = { { x = 1, z = 1, health = 10 } }
	local moves = EnemyAI.planMoves(enemies, { x = 4, z = 1 }, 6)
	assert(#moves == 1, "expected one move")
	assert(moves[1].x == 2 and moves[1].z == 1, "expected a step toward the player along x")
end)

case("planMoves / already-adjacent enemy does not move (capturable by Pawn)", function()
	local enemies = { { x = 3, z = 3, health = 10, pieceType = "Pawn" } }
	-- playerPieceType=Pawn can capture orthogonal adjacent → freeze.
	local moves = EnemyAI.planMoves(enemies, { x = 4, z = 3 }, 6, "Pawn")
	assert(moves[1].x == 3 and moves[1].z == 3, "adjacent capturable enemy should stay put")
end)

case("planMoves / adjacent uncapturable vs Knight keeps moving", function()
	local enemies = { { x = 3, z = 3, health = 10, pieceType = "Pawn" } }
	local moves = EnemyAI.planMoves(enemies, { x = 4, z = 3 }, 6, "Knight")
	assert(
		not (moves[1].x == 3 and moves[1].z == 3),
		"Knight cannot capture adjacent; enemy must not freeze (softlock guard)"
	)
end)

case("planMoves / never proposes a destination another enemy already occupies", function()
	local enemies = { { x = 1, z = 1, health = 10 }, { x = 2, z = 1, health = 10 } }
	local moves = EnemyAI.planMoves(enemies, { x = 6, z = 1 }, 6)
	assert(
		not (moves[1].x == moves[2].x and moves[1].z == moves[2].z),
		"two enemies must not collapse onto the same square"
	)
end)

case("planMoves / never proposes an out-of-bounds destination", function()
	local enemies = { { x = 1, z = 1, health = 10 } }
	local moves = EnemyAI.planMoves(enemies, { x = 1, z = 1 }, 6)
	assert(
		moves[1].x >= 1 and moves[1].x <= 6 and moves[1].z >= 1 and moves[1].z <= 6,
		"destination must stay in bounds"
	)
end)

return function()
	for _, entry in ipairs(cases) do
		local ok, err = pcall(entry.body)
		assert(ok, entry.name .. " FAILED: " .. tostring(err))
	end
	print(string.format("EnemyAI: PASS (%d cases)", #cases))
	return #cases
end

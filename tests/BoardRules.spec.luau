-- tests/BoardRules.spec.luau
local BoardRules = require("../src/shared/BoardRules")

local cases = {}
local function case(name, body)
	table.insert(cases, { name = name, body = body })
end

local function containsMove(moves, x, z)
	for _, move in ipairs(moves) do
		if move.x == x and move.z == z then
			return true
		end
	end
	return false
end

case("Pawn / 4-directional single step, no diagonals", function()
	local moves = BoardRules.legalMoves("Pawn", { x = 3, z = 3 }, 6, {})
	assert(#moves == 4, "expected exactly 4 moves, got " .. #moves)
	assert(containsMove(moves, 4, 3), "missing +x")
	assert(containsMove(moves, 2, 3), "missing -x")
	assert(containsMove(moves, 3, 4), "missing +z")
	assert(containsMove(moves, 3, 2), "missing -z")
	assert(not containsMove(moves, 4, 4), "diagonal must not be legal")
end)

case("Pawn / corner has exactly 2 legal moves (never zero)", function()
	local moves = BoardRules.legalMoves("Pawn", { x = 1, z = 1 }, 6, {})
	assert(#moves == 2, "expected 2 moves at a corner, got " .. #moves)
end)

case("Knight / center has 8 L-shaped targets", function()
	local moves = BoardRules.legalMoves("Knight", { x = 3, z = 3 }, 6, {})
	assert(#moves == 8, "expected 8 knight moves, got " .. #moves)
	assert(containsMove(moves, 5, 4), "missing L-target (5,4)")
	assert(containsMove(moves, 1, 2), "missing L-target (1,2)")
end)

case("Knight / ignores blocking (no path check needed)", function()
	-- An "enemy" sitting between origin and an L-target should not matter --
	-- knight moves are jumps, never blocked. Legality here means "reachable",
	-- separately from whether it's occupied (occupied = attack target).
	local moves = BoardRules.legalMoves("Knight", { x = 3, z = 3 }, 6, { { x = 4, z = 3 } })
	assert(containsMove(moves, 5, 4), "knight jump must ignore intervening pieces")
end)

case("Rook / slides until board edge on an empty board", function()
	local moves = BoardRules.legalMoves("Rook", { x = 1, z = 1 }, 6, {})
	-- 5 squares along +x, 5 along +z (no -x/-z available from a corner) = 10.
	assert(#moves == 10, "expected 10 moves from a corner on an empty 6x6, got " .. #moves)
end)

case("Rook / BLOCKED — stops at (captures) the first enemy, no further", function()
	local moves = BoardRules.legalMoves("Rook", { x = 1, z = 1 }, 6, { { x = 3, z = 1 } })
	assert(containsMove(moves, 2, 1), "square before the enemy must be reachable")
	assert(containsMove(moves, 3, 1), "the enemy's own square must be a legal capture target")
	assert(not containsMove(moves, 4, 1), "must not see past a blocking enemy")
	assert(not containsMove(moves, 5, 1), "must not see past a blocking enemy")
end)

case("BoardRules.enemyAt / detects occupancy", function()
	local enemies = { { x = 2, z = 2 }, { x = 4, z = 4 } }
	assert(BoardRules.enemyAt({ x = 2, z = 2 }, enemies), "should find enemy at (2,2)")
	assert(not BoardRules.enemyAt({ x = 3, z = 3 }, enemies), "should not find enemy at (3,3)")
end)

case("Bishop / diagonal only, blocked by first enemy", function()
	local moves = BoardRules.legalMoves("Bishop", { x = 3, z = 3 }, 6, { { x = 5, z = 5 } })
	local has45 = false
	local pastBlock = false
	for _, move in ipairs(moves) do
		if move.x == 4 and move.z == 4 then
			has45 = true -- wait, 4,4 is before 5,5
		end
		if move.x == 5 and move.z == 5 then
			has45 = true
		end
		if move.x == 6 and move.z == 6 then
			pastBlock = true
		end
	end
	assert(has45, "must reach capture square on diagonal")
	assert(not pastBlock, "must not slide past blocking enemy")
end)

case("King / 8-adjacent single step", function()
	local moves = BoardRules.legalMoves("King", { x = 3, z = 3 }, 6, {})
	assert(#moves == 8, "expected 8 king moves, got " .. #moves)
end)

case("Queen / combines rook and bishop rays", function()
	local moves = BoardRules.legalMoves("Queen", { x = 1, z = 1 }, 6, {})
	-- 5 ortho + 5 diag from corner empty board = 10... wait diag only one way +x+z = 5, ortho +x and +z = 10 total?
	-- ortho 5+5=10, diag 5 = 15
	assert(#moves == 15, "expected 15 queen moves from corner empty 6x6, got " .. #moves)
end)

case("legalMoves / rejects unknown piece type", function()
	local ok = pcall(function()
		BoardRules.legalMoves("Dragon", { x = 3, z = 3 }, 6, {})
	end)
	assert(not ok, "unknown piece type must error")
end)

return function()
	for _, entry in ipairs(cases) do
		local ok, err = pcall(entry.body)
		assert(ok, entry.name .. " FAILED: " .. tostring(err))
	end
	print(string.format("BoardRules: PASS (%d cases)", #cases))
	return #cases
end

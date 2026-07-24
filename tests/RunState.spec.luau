-- tests/RunState.spec.luau
local RunState = require("../src/shared/RunState")
local Config = require("../src/shared/Config")

local cases = {}
local function case(name, body)
	table.insert(cases, { name = name, body = body })
end

local function expectEqual(actual, expected, message)
	assert(
		actual == expected,
		string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual))
	)
end

case("RunState.new / starts unassigned with the full roster", function()
	local state = RunState.new({ "Pawn", "Knight", "Rook" }, 1, Config)
	local snapshot = state:snapshot()
	expectEqual(snapshot.activePiece, nil, "no piece assigned yet")
	expectEqual(#snapshot.roster, 3, "roster should start with all 3 pieces")
end)

case("assignRandomPiece / draws from the roster and removes it", function()
	local state = RunState.new({ "Pawn", "Knight", "Rook" }, 5, Config)
	state:assignRandomPiece()
	local snapshot = state:snapshot()
	assert(snapshot.activePiece ~= nil, "a piece should now be active")
	expectEqual(#snapshot.roster, 2, "roster should shrink by one")
	expectEqual(
		snapshot.activeHealth,
		Config.PIECES[snapshot.activePiece].maxHealth,
		"active piece starts at full health"
	)
	expectEqual(
		snapshot.invulnerable,
		true,
		"freshly assigned piece is invulnerable for its first turn"
	)
end)

case("reroll / returns the rejected piece to the pool and draws again", function()
	local state = RunState.new({ "Pawn", "Knight", "Rook" }, 1, Config)
	state:assignRandomPiece()
	local firstDraw = state:snapshot().activePiece
	local ok = state:reroll()
	assert(ok, "first reroll must be accepted")
	local snapshot = state:snapshot()
	expectEqual(
		#snapshot.roster,
		2,
		"roster size must be unchanged after a reroll (return one, draw one)"
	)
	-- Without-replacement: the rejected piece must not be the new draw.
	assert(
		snapshot.activePiece ~= firstDraw,
		"reroll must not redraw the exact piece just rejected"
	)
end)

case("reroll / rejected once per assignment (REROLL_LIMIT = 1)", function()
	local state = RunState.new({ "Pawn", "Knight", "Rook" }, 1, Config)
	state:assignRandomPiece()
	assert(state:reroll(), "first reroll must succeed")
	assert(not state:reroll(), "second reroll on the same assignment must be rejected")
end)

case("applyPlayerMove / rejects an illegal destination", function()
	local state = RunState.new({ "Pawn" }, 1, Config)
	state:assignRandomPiece()
	local ok = pcall(function()
		state:applyPlayerMove({ x = 6, z = 6 })
	end)
	assert(not ok, "a destination outside legal moves must error")
end)

case("applyPlayerMove / moving into an empty square just moves, no combat", function()
	local state = RunState.new({ "Pawn" }, 1, Config)
	state:assignRandomPiece()
	local destination = state:legalMovesForActive()[1]
	-- Ensure the chosen destination is empty (spawn may have placed an enemy).
	state:_debugSetEnemies({})
	destination = state:legalMovesForActive()[1]
	local result = state:applyPlayerMove(destination)
	expectEqual(result.playerDamageDealt, 0, "no enemy present, no damage dealt")
	expectEqual(result.playerDamageTaken, 0, "no enemy present, no damage taken")
	local after = state:snapshot()
	expectEqual(after.activePosition.x, destination.x, "piece moved to the destination")
	expectEqual(after.activePosition.z, destination.z, "piece moved to the destination")
end)

case(
	"applyPlayerMove / attacking a surviving enemy deals bidirectional damage and does not move",
	function()
		local state = RunState.new({ "Pawn" }, 1, Config)
		state:assignRandomPiece()
		-- Clear first-turn invulnerability so bidirectional damage is observable.
		state:_debugSetInvulnerable(false)
		local origin = state:snapshot().activePosition
		-- Place a very tanky enemy directly adjacent so it's guaranteed to survive one hit.
		state:_debugSetEnemies({
			{ x = origin.x + 1, z = origin.z, health = 9999, maxHealth = 9999, attack = 2 },
		})
		local result = state:applyPlayerMove({ x = origin.x + 1, z = origin.z })
		assert(result.playerDamageDealt > 0, "should have dealt damage")
		assert(result.playerDamageTaken == 2, "enemy attack is 2")
		assert(not result.enemyDied, "the tanky enemy should survive")
		local after = state:snapshot()
		expectEqual(after.activePosition.x, origin.x, "attacker stays put when the target survives")
		expectEqual(after.activePosition.z, origin.z, "attacker stays put when the target survives")
	end
)

case("applyPlayerMove / killing an enemy captures the square (lands on it)", function()
	local state = RunState.new({ "Pawn" }, 1, Config)
	state:assignRandomPiece()
	local origin = state:snapshot().activePosition
	-- Second enemy far away so level does not auto-advance on this kill.
	state:_debugSetEnemies({
		{ x = origin.x + 1, z = origin.z, health = 1, maxHealth = 1, attack = 0 },
		{ x = 1, z = 1, health = 10, maxHealth = 10, attack = 0 },
	})
	local result = state:applyPlayerMove({ x = origin.x + 1, z = origin.z })
	assert(result.enemyDied, "a 1-HP enemy must die to any positive damage")
	local after = state:snapshot()
	expectEqual(
		after.activePosition.x,
		origin.x + 1,
		"capturing piece lands on the now-empty square"
	)
	expectEqual(#after.enemies, 1, "dead enemy removed; distant survivor remains")
	expectEqual(after.enemies[1].x, 1, "surviving enemy is the far one")
end)

case("applyPlayerMove / Rook pierce damages a second enemy behind the first", function()
	local state = RunState.new({ "Rook" }, 1, Config)
	state:assignRandomPiece()
	local origin = state:snapshot().activePosition
	state:_debugSetEnemies({
		{ x = origin.x + 1, z = origin.z, health = 1, maxHealth = 1, attack = 0 },
		-- Survive pierce (Rook ATK 5, crit up to 7.5) so the case can inspect residual HP.
		{ x = origin.x + 2, z = origin.z, health = 100, maxHealth = 100, attack = 0 },
	})
	local result = state:applyPlayerMove({ x = origin.x + 1, z = origin.z })
	assert(result.pierced, "expected the pierce flag to be set")
	local after = state:snapshot()
	local pierced = after.enemies[1]
	expectEqual(pierced.x, origin.x + 2, "pierced enemy is the one behind the first")
	assert(pierced.health < 100, "pierced enemy must have taken damage")
end)

case("applyPlayerMove / roster exhausted ends the run", function()
	local state = RunState.new({ "Pawn" }, 1, Config)
	state:assignRandomPiece()
	-- Force the active piece's health to 1 and have it walk into a lethal enemy.
	state:_debugSetInvulnerable(false)
	state:_debugSetActiveHealth(1)
	local origin = state:snapshot().activePosition
	state:_debugSetEnemies({
		{ x = origin.x + 1, z = origin.z, health = 9999, maxHealth = 9999, attack = 50 },
	})
	local result = state:applyPlayerMove({ x = origin.x + 1, z = origin.z })
	assert(result.runOver, "roster had only 1 piece; its death must end the run")
end)

case("applyPlayerMove / death with pieces remaining redraws via safe respawn", function()
	local state = RunState.new({ "Pawn", "Knight" }, 3, Config)
	state:assignRandomPiece()
	state:_debugSetInvulnerable(false)
	state:_debugSetActiveHealth(1)
	local origin = state:snapshot().activePosition
	state:_debugSetEnemies({
		{ x = origin.x + 1, z = origin.z, health = 9999, maxHealth = 9999, attack = 50 },
	})
	local result = state:applyPlayerMove({ x = origin.x + 1, z = origin.z })
	assert(not result.runOver, "one piece remains, the run must continue")
	local after = state:snapshot()
	assert(after.activePiece ~= nil, "a new piece must be assigned")
	expectEqual(after.invulnerable, true, "the redrawn piece is invulnerable for its first turn")
end)

case("snapshot / exposes legalMoves, phase, and rerollsRemaining", function()
	local state = RunState.new({ "Pawn" }, 1, Config)
	state:assignRandomPiece()
	state:_debugSetEnemies({})
	local snapshot = state:snapshot()
	assert(
		type(snapshot.legalMoves) == "table" and #snapshot.legalMoves > 0,
		"expected legal moves"
	)
	expectEqual(snapshot.phase, "Turn", "fresh run is Turn phase")
	expectEqual(snapshot.rerollsRemaining, 1, "one reroll available after assign")
	expectEqual(snapshot.runOver, false, "run is not over")
	assert(type(snapshot.previews) == "table", "previews present")
end)

case("applyPlayerMove / King takes half incoming damage", function()
	local state = RunState.new({ "King" }, 1, Config)
	state:assignRandomPiece()
	state:_debugSetInvulnerable(false)
	local origin = state:snapshot().activePosition
	state:_debugSetEnemies({
		{ x = origin.x + 1, z = origin.z, health = 9999, maxHealth = 9999, attack = 10 },
	})
	local result = state:applyPlayerMove({ x = origin.x + 1, z = origin.z })
	expectEqual(result.playerDamageTaken, 5, "King incoming ×0.5 on attack 10")
end)

case("applyPlayerMove / Queen takes 1.5x incoming damage", function()
	local state = RunState.new({ "Queen" }, 1, Config)
	state:assignRandomPiece()
	state:_debugSetInvulnerable(false)
	local origin = state:snapshot().activePosition
	state:_debugSetEnemies({
		{ x = origin.x + 1, z = origin.z, health = 9999, maxHealth = 9999, attack = 4 },
	})
	local result = state:applyPlayerMove({ x = origin.x + 1, z = origin.z })
	expectEqual(result.playerDamageTaken, 6, "Queen incoming ×1.5 on attack 4")
end)

case("applyPlayerMove / King boss kill forces victory over mutual KO", function()
	local state = RunState.new({ "Pawn" }, 1, Config)
	state:assignRandomPiece()
	state:_debugSetInvulnerable(false)
	state:_debugSetActiveHealth(1)
	local origin = state:snapshot().activePosition
	state:_debugSetEnemies({
		{
			x = origin.x + 1,
			z = origin.z,
			health = 1,
			maxHealth = 1,
			attack = 999,
			pieceType = "King",
			isBoss = true,
			incomingDamageMultiplier = 1,
		},
	})
	local result = state:applyPlayerMove({ x = origin.x + 1, z = origin.z })
	assert(result.victory, "boss kill is victory")
	assert(result.bossKilled, "bossKilled flag")
	local snap = state:snapshot()
	assert(snap.phase == "Victory", "Victory phase")
	assert(snap.activeHealth == 1, "mutual KO must not kill player on boss clear")
end)

case("spawn / king boss stage has one boss", function()
	local state = RunState.new({ "Pawn" }, 7, Config, { transcendenceLevel = 1 })
	state:assignRandomPiece()
	-- Jump to king-boss level by clearing and setting level
	state.level = 17
	state:_debugSetEnemies({})
	-- force spawn via empty enemies + level clear path: call internal by clearing all
	-- Use apply empty board level bump: set level 16, kill last enemy
	state.level = 16
	state:_debugSetEnemies({
		{
			x = 1,
			z = 1,
			health = 1,
			maxHealth = 1,
			attack = 0,
			pieceType = "Queen",
			isBoss = false,
			incomingDamageMultiplier = 1,
		},
	})
	state.activePosition = { x = 2, z = 1 }
	state.activePiece = "Rook"
	state:_debugSetInvulnerable(true)
	state:applyPlayerMove({ x = 1, z = 1 })
	local snap = state:snapshot()
	assert(snap.level == 17, "advanced to 17")
	local bosses = 0
	for _, e in ipairs(snap.enemies) do
		if e.isBoss then
			bosses += 1
		end
	end
	assert(bosses == 1, "exactly one king boss")
end)

return function()
	for _, entry in ipairs(cases) do
		local ok, err = pcall(entry.body)
		assert(ok, entry.name .. " FAILED: " .. tostring(err))
	end
	print(string.format("RunState: PASS (%d cases)", #cases))
	return #cases
end

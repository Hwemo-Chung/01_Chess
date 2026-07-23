-- tests/RunController.spec.luau
local RunController = require("../src/server/RunController")

local cases = {}
local function case(name, body)
	table.insert(cases, { name = name, body = body })
end

local function newController()
	return RunController.new({
		clock = function()
			return 0
		end,
		seedForPlayer = function(userId)
			return userId
		end,
	})
end

case("start / creates a run and assigns a piece immediately", function()
	local controller = newController()
	controller:start(1, { "Pawn", "Knight", "Rook" })
	local snapshot = controller:snapshot(1)
	assert(snapshot ~= nil, "expected a snapshot for player 1")
	assert(snapshot.activePiece ~= nil, "a piece should be assigned on start")
end)

case("submitMove / applies a legal move and returns the result", function()
	local controller = newController()
	controller:start(1, { "Pawn" })
	local before = controller:snapshot(1)
	-- Clear enemies so the first legal move is always empty-square movement.
	controller.runs[1]:_debugSetEnemies({})
	local destination = controller.runs[1]:legalMovesForActive()[1]
	local result = controller:submitMove(1, destination.x, destination.z)
	assert(result ~= nil, "expected a move result")
	local after = controller:snapshot(1)
	assert(
		after.activePosition.x ~= before.activePosition.x
			or after.activePosition.z ~= before.activePosition.z,
		"position should change"
	)
end)

case("submitMove / unknown player is rejected", function()
	local controller = newController()
	local ok, err = pcall(function()
		controller:submitMove(999, 1, 1)
	end)
	assert(not ok, "unknown player must error: " .. tostring(err))
end)

case("requestReroll / delegates to RunState and respects the once-per-assignment limit", function()
	local controller = newController()
	controller:start(1, { "Pawn", "Knight" })
	assert(controller:requestReroll(1), "first reroll should succeed")
	assert(not controller:requestReroll(1), "second reroll on the same assignment should fail")
end)

case("snapshot / returns nil for a player with no active run", function()
	local controller = newController()
	assert(controller:snapshot(42) == nil, "expected nil for an unknown player")
end)

return function()
	for _, entry in ipairs(cases) do
		local ok, err = pcall(entry.body)
		assert(ok, entry.name .. " FAILED: " .. tostring(err))
	end
	print(string.format("RunController: PASS (%d cases)", #cases))
	return #cases
end

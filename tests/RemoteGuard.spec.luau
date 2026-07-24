-- tests/RemoteGuard.spec.luau
local RemoteGuard = require("../src/server/RemoteGuard")

local cases = {}
local function case(name, body)
	table.insert(cases, { name = name, body = body })
end

local function fixedClock()
	local now = 0
	return function()
		return now
	end, function(delta)
		now += delta
	end
end

case("validateMove / accepts two numeric args during Turn phase", function()
	local clock = fixedClock()
	local guard = RemoteGuard.new(clock)
	local result = guard:validateMove(1, { argc = 2, args = { 3, 4 } }, { phase = "Turn" })
	assert(result.accepted, "expected acceptance, got reason=" .. result.reason)
end)

case("validateMove / rejects wrong argument count", function()
	local clock = fixedClock()
	local guard = RemoteGuard.new(clock)
	local result = guard:validateMove(1, { argc = 1, args = { 3 } }, { phase = "Turn" })
	assert(not result.accepted and result.reason == "bad_arguments", "expected bad_arguments")
end)

case("validateMove / rejects non-numeric coordinates", function()
	local clock = fixedClock()
	local guard = RemoteGuard.new(clock)
	local result = guard:validateMove(1, { argc = 2, args = { "x", 4 } }, { phase = "Turn" })
	assert(not result.accepted and result.reason == "bad_arguments", "expected bad_arguments")
end)

case("validateMove / rejects wrong phase", function()
	local clock = fixedClock()
	local guard = RemoteGuard.new(clock)
	local result = guard:validateMove(
		1,
		{ argc = 2, args = { 3, 4 } },
		{ phase = "AwaitingAssignment" }
	)
	assert(not result.accepted and result.reason == "wrong_phase", "expected wrong_phase")
end)

case("validateMove / rate limited past 4 accepted requests per second", function()
	local clock, advance = fixedClock()
	local guard = RemoteGuard.new(clock)
	for i = 1, 4 do
		local result = guard:validateMove(1, { argc = 2, args = { 3, 4 } }, { phase = "Turn" })
		assert(result.accepted, "request " .. i .. " should be accepted")
	end
	local fifth = guard:validateMove(1, { argc = 2, args = { 3, 4 } }, { phase = "Turn" })
	assert(
		not fifth.accepted and fifth.reason == "rate_limited",
		"5th request within the window must be rate limited"
	)
	advance(1.1)
	local sixth = guard:validateMove(1, { argc = 2, args = { 3, 4 } }, { phase = "Turn" })
	assert(sixth.accepted, "request after the window elapses must be accepted")
end)

case(
	"validateReroll / accepts zero-argument requests during Turn phase, rate limited to 1/sec",
	function()
		local clock, advance = fixedClock()
		local guard = RemoteGuard.new(clock)
		local first = guard:validateReroll(1, { argc = 0, args = {} }, { phase = "Turn" })
		assert(first.accepted, "first reroll request should be accepted")
		local second = guard:validateReroll(1, { argc = 0, args = {} }, { phase = "Turn" })
		assert(
			not second.accepted and second.reason == "rate_limited",
			"second reroll within the window must be rate limited"
		)
		advance(1.1)
		local third = guard:validateReroll(1, { argc = 0, args = {} }, { phase = "Turn" })
		assert(third.accepted, "reroll after the window elapses must be accepted")
	end
)

case("validateRestart / accepts GameOver and Victory, rejects Turn", function()
	local clock, advance = fixedClock()
	local guard = RemoteGuard.new(clock)
	local bad = guard:validateRestart(1, { argc = 0, args = {} }, { phase = "Turn" })
	assert(not bad.accepted and bad.reason == "wrong_phase", "restart during Turn must fail")
	local ok = guard:validateRestart(1, { argc = 0, args = {} }, { phase = "GameOver" })
	assert(ok.accepted, "restart during GameOver must succeed")
	advance(1.1)
	local ok2 = guard:validateRestart(1, { argc = 0, args = {} }, { phase = "Victory" })
	assert(ok2.accepted, "restart during Victory must succeed")
end)

case("validateTranscend / Victory only", function()
	local clock = fixedClock()
	local guard = RemoteGuard.new(clock)
	local bad = guard:validateTranscend(1, { argc = 0, args = {} }, { phase = "GameOver" })
	assert(not bad.accepted, "no transcend on GameOver")
	local ok = guard:validateTranscend(1, { argc = 0, args = {} }, { phase = "Victory" })
	assert(ok.accepted, "transcend on Victory")
end)

return function()
	for _, entry in ipairs(cases) do
		local ok, err = pcall(entry.body)
		assert(ok, entry.name .. " FAILED: " .. tostring(err))
	end
	print(string.format("RemoteGuard: PASS (%d cases)", #cases))
	return #cases
end

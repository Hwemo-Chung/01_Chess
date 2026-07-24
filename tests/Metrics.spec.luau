local Metrics = require("../src/shared/Metrics")

local cases = {}
local function case(name, body)
	table.insert(cases, { name = name, body = body })
end

case("session counters track start/end/restart/rounds", function()
	local t = 0
	local m = Metrics.new(function()
		t += 1
		return t
	end)
	m:recordRunStart()
	m:recordRound()
	m:recordRound()
	m:recordRunEnd(3, "roster_exhausted")
	m:recordRestartAfterLoss()
	m:recordRunStart()
	assert(m.runsStarted == 2, "runsStarted")
	assert(m.runsEnded == 1, "runsEnded")
	assert(m.restartsAfterLoss == 1, "restarts")
	assert(m.roundsThisSession == 2, "rounds")
	assert(m:restartAfterLossRate() == 1, "rate after one ended run and one restart")
end)

return function()
	for _, entry in ipairs(cases) do
		local ok, err = pcall(entry.body)
		assert(ok, entry.name .. " FAILED: " .. tostring(err))
	end
	print(string.format("Metrics: PASS (%d cases)", #cases))
	return #cases
end

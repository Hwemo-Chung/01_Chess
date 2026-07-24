-- tests/run.luau
local process = require("@lune/process")

local filter = nil
for index, argument in ipairs(process.args) do
	if argument == "--filter" then
		filter = process.args[index + 1]
	end
end

local suites = {
	Rng = function()
		return require("./Rng.spec")
	end,
	BoardRules = function()
		return require("./BoardRules.spec")
	end,
	CombatRules = function()
		return require("./CombatRules.spec")
	end,
	SpawnRules = function()
		return require("./SpawnRules.spec")
	end,
	RunState = function()
		return require("./RunState.spec")
	end,
	RemoteGuard = function()
		return require("./RemoteGuard.spec")
	end,
	RunController = function()
		return require("./RunController.spec")
	end,
	EnemyAI = function()
		return require("./EnemyAI.spec")
	end,
	BoardLayout = function()
		return require("./BoardLayout.spec")
	end,
	ProfileRules = function()
		return require("./ProfileRules.spec")
	end,
	Metrics = function()
		return require("./Metrics.spec")
	end,
	Transcendence = function()
		return require("./Transcendence.spec")
	end,
}

local total = 0
for name, loadSuite in pairs(suites) do
	if filter == nil or string.find(name, filter, 1, true) ~= nil then
		local runSuite = loadSuite()
		total += runSuite()
	end
end

assert(total > 0, "no tests matched filter")
print(string.format("TEST SUMMARY: PASS (%d named cases)", total))

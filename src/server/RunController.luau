-- Server-authoritative wrapper around one RunState per player.
local RunController = {}
RunController.__index = RunController

local function resolveModule(injected, relativePath: string)
	if injected ~= nil then
		return injected
	end
	return require(relativePath)
end

function RunController.new(dependencies)
	assert(type(dependencies) == "table", "dependencies must be a table")
	assert(type(dependencies.clock) == "function", "clock must be a function")
	assert(type(dependencies.seedForPlayer) == "function", "seedForPlayer must be a function")
	return setmetatable({
		_dependencies = dependencies,
		_RunState = resolveModule(dependencies.RunState, "../shared/RunState"),
		_Config = resolveModule(dependencies.Config, "../shared/Config"),
		runs = {},
	}, RunController)
end

function RunController.start(self, playerUserId: number, roster: { string })
	local seed = self._dependencies.seedForPlayer(playerUserId)
	local state = self._RunState.new(roster, seed, self._Config)
	state:assignRandomPiece()
	self.runs[playerUserId] = state
end

function RunController.submitMove(self, playerUserId: number, x: number, z: number)
	local state = self.runs[playerUserId]
	assert(state ~= nil, "no active run for player " .. tostring(playerUserId))
	return state:applyPlayerMove({ x = x, z = z })
end

function RunController.requestReroll(self, playerUserId: number): boolean
	local state = self.runs[playerUserId]
	assert(state ~= nil, "no active run for player " .. tostring(playerUserId))
	assert(not state.runOver, "run is over")
	return state:reroll()
end

function RunController.restart(self, playerUserId: number, roster: { string })
	self:start(playerUserId, roster)
end

function RunController.snapshot(self, playerUserId: number)
	local state = self.runs[playerUserId]
	if state == nil then
		return nil
	end
	return state:snapshot()
end

function RunController.clear(self, playerUserId: number)
	self.runs[playerUserId] = nil
end

return RunController

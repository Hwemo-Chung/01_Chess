-- Pure validation and per-player accepted-request windows for untrusted
-- remote ingress.
local RemoteGuard = {}
RemoteGuard.__index = RemoteGuard

local MOVE_LIMIT = 4
local REROLL_LIMIT = 1
local RESTART_LIMIT = 1
local BUY_LIMIT = 2
local WINDOW_SECONDS = 1

local function result(accepted: boolean, reason: string)
	return { accepted = accepted, reason = reason }
end

local function exactArgs(wire, expected: number): boolean
	if type(wire) ~= "table" or wire.argc ~= expected or type(wire.args) ~= "table" then
		return false
	end
	for index = 1, expected do
		if wire.args[index] == nil then
			return false
		end
	end
	return true
end

local function acceptedAt(clock, windows, userId, limit, windowSeconds): boolean
	local now = clock()
	local previous = windows[userId] or {}
	local retained = {}
	for _, timestamp in ipairs(previous) do
		if timestamp > now - windowSeconds then
			table.insert(retained, timestamp)
		end
	end
	if #retained >= limit then
		windows[userId] = retained
		return false
	end
	table.insert(retained, now)
	windows[userId] = retained
	return true
end

function RemoteGuard.new(clock: () -> number)
	assert(type(clock) == "function", "clock must be a function")
	return setmetatable({
		_clock = clock,
		_moveWindows = {},
		_rerollWindows = {},
		_restartWindows = {},
		_buyWindows = {},
	}, RemoteGuard)
end

function RemoteGuard.validateMove(self, playerUserId: number, wire, snapshot)
	if
		not exactArgs(wire, 2)
		or type(wire.args[1]) ~= "number"
		or type(wire.args[2]) ~= "number"
	then
		return result(false, "bad_arguments")
	end
	if type(snapshot) ~= "table" or snapshot.phase ~= "Turn" then
		return result(false, "wrong_phase")
	end
	if not acceptedAt(self._clock, self._moveWindows, playerUserId, MOVE_LIMIT, WINDOW_SECONDS) then
		return result(false, "rate_limited")
	end
	return result(true, "ok")
end

function RemoteGuard.validateReroll(self, playerUserId: number, wire, snapshot)
	if not exactArgs(wire, 0) then
		return result(false, "bad_arguments")
	end
	if type(snapshot) ~= "table" or snapshot.phase ~= "Turn" then
		return result(false, "wrong_phase")
	end
	if
		not acceptedAt(self._clock, self._rerollWindows, playerUserId, REROLL_LIMIT, WINDOW_SECONDS)
	then
		return result(false, "rate_limited")
	end
	return result(true, "ok")
end

function RemoteGuard.validateRestart(self, playerUserId: number, wire, snapshot)
	if not exactArgs(wire, 0) then
		return result(false, "bad_arguments")
	end
	if type(snapshot) ~= "table" or snapshot.phase ~= "GameOver" then
		return result(false, "wrong_phase")
	end
	if
		not acceptedAt(
			self._clock,
			self._restartWindows,
			playerUserId,
			RESTART_LIMIT,
			WINDOW_SECONDS
		)
	then
		return result(false, "rate_limited")
	end
	return result(true, "ok")
end

function RemoteGuard.validateBuy(self, playerUserId: number, wire, snapshot)
	if not exactArgs(wire, 1) or type(wire.args[1]) ~= "string" then
		return result(false, "bad_arguments")
	end
	-- Shop is available between runs only (GameOver / Lobby).
	if type(snapshot) ~= "table" then
		return result(false, "wrong_phase")
	end
	if snapshot.phase ~= "GameOver" and snapshot.phase ~= "Lobby" then
		return result(false, "wrong_phase")
	end
	if not acceptedAt(self._clock, self._buyWindows, playerUserId, BUY_LIMIT, WINDOW_SECONDS) then
		return result(false, "rate_limited")
	end
	return result(true, "ok")
end

return RemoteGuard

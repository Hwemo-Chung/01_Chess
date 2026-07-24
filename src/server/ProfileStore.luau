-- Session profile store with injectable DataStore. Fail-soft under Lune:
-- in-memory map when no real store is provided.
local ProfileStore = {}
ProfileStore.__index = ProfileStore

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in pairs(value) do
		result[key] = copy(child)
	end
	return result
end

function ProfileStore.new(dependencies)
	assert(type(dependencies) == "table", "dependencies must be a table")
	assert(type(dependencies.config) == "table", "config required")
	local ProfileRules = dependencies.ProfileRules
	if ProfileRules == nil then
		ProfileRules = require("../shared/ProfileRules")
	end
	return setmetatable({
		_config = dependencies.config,
		_ProfileRules = ProfileRules,
		_getDataStore = dependencies.getDataStore, -- optional () -> DataStore-like
		_clock = dependencies.clock or os.clock,
		_memory = {},
		_sessions = {},
	}, ProfileStore)
end

local function keyFor(userId: number): string
	return "ChessPlayer_" .. tostring(userId)
end

function ProfileStore:load(userId: number)
	if self._sessions[userId] ~= nil then
		return true, copy(self._sessions[userId].profile), nil
	end

	local raw = nil
	if self._getDataStore ~= nil then
		local store = self._getDataStore()
		local ok, value = pcall(function()
			return store:GetAsync(keyFor(userId))
		end)
		if ok then
			raw = value
		else
			warn("[CHESS_PROFILE] GetAsync failed: " .. tostring(value))
		end
	else
		raw = self._memory[userId]
	end

	local outcome, profile = self._ProfileRules.normalize(raw, self._config)
	if profile == nil then
		return false, nil, outcome
	end
	self._sessions[userId] = { profile = profile, dirty = false }
	return true, copy(profile), nil
end

function ProfileStore:get(userId: number)
	local session = self._sessions[userId]
	if session == nil then
		return nil
	end
	return copy(session.profile)
end

function ProfileStore:set(userId: number, profile)
	assert(self._sessions[userId] ~= nil, "profile not loaded")
	self._sessions[userId].profile = copy(profile)
	self._sessions[userId].dirty = true
end

function ProfileStore:save(userId: number): boolean
	local session = self._sessions[userId]
	if session == nil then
		return false
	end
	local profile = session.profile
	if self._getDataStore ~= nil then
		local store = self._getDataStore()
		local ok, err = pcall(function()
			store:SetAsync(keyFor(userId), profile)
		end)
		if not ok then
			warn("[CHESS_PROFILE] SetAsync failed: " .. tostring(err))
			return false
		end
	else
		self._memory[userId] = copy(profile)
	end
	session.dirty = false
	return true
end

function ProfileStore:release(userId: number)
	if self._sessions[userId] ~= nil then
		self:save(userId)
		self._sessions[userId] = nil
	end
end

return ProfileStore

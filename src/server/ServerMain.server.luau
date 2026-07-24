local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local RunController = require(script.Parent.RunController)
local RemoteGuard = require(script.Parent.RemoteGuard)
local EnemyAI = require(script.Parent.EnemyAI)
local ProfileStore = require(script.Parent.ProfileStore)

local Shared = ReplicatedStorage:WaitForChild("Chess"):WaitForChild("Shared")
local RunState = require(Shared:WaitForChild("RunState"))
local Config = require(Shared:WaitForChild("Config"))
local ProfileRules = require(Shared:WaitForChild("ProfileRules"))
local Metrics = require(Shared:WaitForChild("Metrics"))

local controller = RunController.new({
	clock = os.clock,
	seedForPlayer = function(userId)
		return (userId * 10007 + math.floor(os.clock() * 1000)) % 2147483646 + 1
	end,
	RunState = RunState,
	Config = Config,
})
local guard = RemoteGuard.new(os.clock)

local profileStore = ProfileStore.new({
	config = Config,
	ProfileRules = ProfileRules,
	getDataStore = function()
		return DataStoreService:GetDataStore("ChessProfiles_v1")
	end,
	clock = os.clock,
})

local sessionMetrics: { [number]: any } = {}
local lastResults: { [number]: any } = {}
local pendingLoss: { [number]: boolean } = {}
local settled: { [number]: boolean } = {}

local chess = ReplicatedStorage:FindFirstChild("Chess")
if chess == nil then
	chess = Instance.new("Folder")
	chess.Name = "Chess"
	chess.Parent = ReplicatedStorage
end
local remotes = chess:FindFirstChild("Remotes")
if remotes == nil then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = chess
end

local function ensureRemoteEvent(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing ~= nil and not existing:IsA("RemoteEvent") then
		existing:Destroy()
		existing = nil
	end
	if existing == nil then
		existing = Instance.new("RemoteEvent")
		existing.Name = name
		existing.Parent = parent
	end
	return existing
end

local submitMove = ensureRemoteEvent(remotes, "SubmitMove")
local requestReroll = ensureRemoteEvent(remotes, "RequestReroll")
local requestRestart = ensureRemoteEvent(remotes, "RequestRestart")
local requestBuy = ensureRemoteEvent(remotes, "RequestBuy")
local requestBuyUpgrade = ensureRemoteEvent(remotes, "RequestBuyUpgrade")
local requestTranscend = ensureRemoteEvent(remotes, "RequestTranscend")
local stateSync = ensureRemoteEvent(remotes, "StateSync")

local function logMetric(userId: number, metrics)
	local snap = metrics:snapshot()
	print(
		string.format(
			"[CHESS_METRICS] userId=%d runsStarted=%d runsEnded=%d restartsAfterLoss=%d rate=%.3f roundsSession=%d",
			userId,
			snap.runsStarted,
			snap.runsEnded,
			snap.restartsAfterLoss,
			snap.restartAfterLossRate,
			snap.roundsThisSession
		)
	)
end

local function applyEnemyTurn(playerUserId: number)
	local state = controller.runs[playerUserId]
	if state == nil or state.activePiece == nil or state.runOver or state.victory then
		return
	end
	local destinations =
		EnemyAI.planMoves(state.enemies, state.activePosition, Config.BOARD_SIZE, state.activePiece)
	for index, destination in ipairs(destinations) do
		local enemy = state.enemies[index]
		if enemy ~= nil then
			enemy.x = destination.x
			enemy.z = destination.z
		end
	end
end

local function runOptions(profile)
	return {
		upgrades = profile.upgrades,
		transcendenceLevel = profile.transcendenceLevel,
	}
end

local function publish(player, lastResult: any?)
	local snapshot = controller:snapshot(player.UserId)
	local profile = profileStore:get(player.UserId)
	local metrics = sessionMetrics[player.UserId]

	if snapshot == nil then
		snapshot = {
			phase = "Lobby",
			runOver = true,
			victory = false,
			legalMoves = {},
			enemies = {},
			previews = {},
			roster = profile and profile.roster or {},
			level = 0,
			activePiece = nil,
			activeHealth = 0,
			activeMaxHealth = 0,
			activePosition = { x = 3, z = 3 },
			invulnerable = false,
			rerollsRemaining = 0,
			roundsPlayed = 0,
			currentTier = "Pawn",
			transcendenceLevel = profile and profile.transcendenceLevel or 1,
		}
	end

	if lastResult ~= nil then
		lastResults[player.UserId] = lastResult
	end
	snapshot.lastResult = lastResults[player.UserId]
	snapshot.profile = profile
	snapshot.metrics = if metrics then metrics:snapshot() else nil

	snapshot.shop = {}
	for pieceName, stats in pairs(Config.PIECES) do
		table.insert(snapshot.shop, {
			kind = "piece",
			id = pieceName,
			piece = pieceName,
			price = stats.price,
			canBuy = profile ~= nil and select(1, ProfileRules.canBuy(profile, pieceName, Config)),
		})
	end
	table.sort(snapshot.shop, function(a, b)
		return a.price < b.price
	end)

	snapshot.upgradeShop = {}
	for name, def in pairs(Config.UPGRADES) do
		local level = profile and profile.upgrades[name] or 0
		table.insert(snapshot.upgradeShop, {
			id = name,
			displayName = def.displayName,
			price = def.price,
			level = level,
			maxLevel = def.maxLevel,
			canBuy = profile ~= nil
				and select(1, ProfileRules.canBuyUpgrade(profile, name, Config)),
		})
	end
	table.sort(snapshot.upgradeShop, function(a, b)
		return a.id < b.id
	end)

	player:SetAttribute("ActivePiece", snapshot.activePiece)
	player:SetAttribute("ActiveHealth", snapshot.activeHealth or 0)
	player:SetAttribute("ActiveMaxHealth", snapshot.activeMaxHealth or 0)
	player:SetAttribute("Level", snapshot.level or 0)
	player:SetAttribute("PositionX", snapshot.activePosition and snapshot.activePosition.x or 0)
	player:SetAttribute("PositionZ", snapshot.activePosition and snapshot.activePosition.z or 0)
	player:SetAttribute("RosterCount", snapshot.roster and #snapshot.roster or 0)
	player:SetAttribute("EnemyCount", snapshot.enemies and #snapshot.enemies or 0)
	player:SetAttribute("Invulnerable", snapshot.invulnerable == true)
	player:SetAttribute("RunOver", snapshot.runOver == true)
	player:SetAttribute("Victory", snapshot.victory == true)
	player:SetAttribute("RerollsRemaining", snapshot.rerollsRemaining or 0)
	player:SetAttribute("Phase", snapshot.phase)
	player:SetAttribute("Currency", profile and profile.currency or 0)
	player:SetAttribute("Transcendence", profile and profile.transcendenceLevel or 1)
	player:SetAttribute("CurrentTier", snapshot.currentTier or "")

	stateSync:FireClient(player, snapshot)
end

local function settleRunEnd(player, reason: string)
	local userId = player.UserId
	if settled[userId] then
		return
	end
	local snapshot = controller:snapshot(userId)
	if snapshot == nil then
		return
	end
	local profile = profileStore:get(userId)
	local metrics = sessionMetrics[userId]
	if profile == nil or metrics == nil then
		return
	end

	local outcome = if reason == "victory" then "victory" else "defeat"
	local updated, payout =
		ProfileRules.awardRunEnd(profile, snapshot.level, snapshot.roundsPlayed, Config, outcome)
	profileStore:set(userId, updated)
	profileStore:save(userId)
	metrics:recordRunEnd(snapshot.level, reason)
	settled[userId] = true
	if outcome == "defeat" then
		pendingLoss[userId] = true
	else
		pendingLoss[userId] = false
	end
	logMetric(userId, metrics)
	print(
		string.format(
			"[CHESS_ECONOMY] userId=%d outcome=%s payout=%d currency=%d T=%d",
			userId,
			outcome,
			payout,
			updated.currency,
			updated.transcendenceLevel
		)
	)
end

local function startRun(player)
	local userId = player.UserId
	local profile = profileStore:get(userId)
	assert(profile ~= nil, "profile required")
	local metrics = sessionMetrics[userId]
	if metrics == nil then
		metrics = Metrics.new(os.clock)
		sessionMetrics[userId] = metrics
	end

	if pendingLoss[userId] then
		local nextProfile = ProfileRules.recordRestartAfterLoss(profile)
		profileStore:set(userId, nextProfile)
		profile = nextProfile
		metrics:recordRestartAfterLoss()
		pendingLoss[userId] = false
	end

	local started = ProfileRules.recordRunStart(profile)
	profileStore:set(userId, started)
	metrics:recordRunStart()
	settled[userId] = false
	controller:start(userId, started.roster, runOptions(started))
	lastResults[userId] = nil
	publish(player, nil)
end

submitMove.OnServerEvent:Connect(function(player, ...)
	local packed = table.pack(...)
	local snapshot = controller:snapshot(player.UserId)
	local phase = if snapshot ~= nil then snapshot.phase else "NoRun"
	local validated = guard:validateMove(player.UserId, {
		argc = select("#", ...),
		args = packed,
	}, { phase = phase })
	if not validated.accepted then
		warn(string.format("[CHESS_SECURITY] rejected SubmitMove reason=%s", validated.reason))
		return
	end
	local moveResult = nil
	local ok, err = pcall(function()
		moveResult = controller:submitMove(player.UserId, packed[1], packed[2])
		local metrics = sessionMetrics[player.UserId]
		if metrics ~= nil then
			metrics:recordRound()
		end
		if moveResult ~= nil and not moveResult.runOver and not moveResult.victory then
			applyEnemyTurn(player.UserId)
		end
	end)
	if not ok then
		warn(string.format("[CHESS_SECURITY] SubmitMove failed: %s", tostring(err)))
		return
	end
	if moveResult ~= nil then
		if moveResult.victory then
			settleRunEnd(player, "victory")
		elseif moveResult.runOver then
			settleRunEnd(player, "roster_exhausted")
		end
	end
	publish(player, moveResult)
end)

requestReroll.OnServerEvent:Connect(function(player, ...)
	local packed = table.pack(...)
	local snapshot = controller:snapshot(player.UserId)
	local phase = if snapshot ~= nil then snapshot.phase else "NoRun"
	local validated = guard:validateReroll(player.UserId, {
		argc = select("#", ...),
		args = packed,
	}, { phase = phase })
	if not validated.accepted then
		warn(string.format("[CHESS_SECURITY] rejected RequestReroll reason=%s", validated.reason))
		return
	end
	local ok, err = pcall(function()
		controller:requestReroll(player.UserId)
	end)
	if not ok then
		warn(string.format("[CHESS_SECURITY] RequestReroll failed: %s", tostring(err)))
		return
	end
	lastResults[player.UserId] = nil
	publish(player, nil)
end)

requestRestart.OnServerEvent:Connect(function(player, ...)
	local packed = table.pack(...)
	local snapshot = controller:snapshot(player.UserId)
	local phase = if snapshot ~= nil then snapshot.phase else "NoRun"
	local validated = guard:validateRestart(player.UserId, {
		argc = select("#", ...),
		args = packed,
	}, { phase = phase })
	if not validated.accepted then
		warn(string.format("[CHESS_SECURITY] rejected RequestRestart reason=%s", validated.reason))
		return
	end
	startRun(player)
end)

requestBuy.OnServerEvent:Connect(function(player, ...)
	local packed = table.pack(...)
	local snapshot = controller:snapshot(player.UserId)
	local phase = if snapshot ~= nil then snapshot.phase else "Lobby"
	local validated = guard:validateBuy(player.UserId, {
		argc = select("#", ...),
		args = packed,
	}, { phase = phase })
	if not validated.accepted then
		warn(string.format("[CHESS_SECURITY] rejected RequestBuy reason=%s", validated.reason))
		return
	end
	local pieceType = packed[1]
	local profile = profileStore:get(player.UserId)
	if profile == nil then
		return
	end
	local okBuy, nextProfile, reason = ProfileRules.buy(profile, pieceType, Config)
	if not okBuy or nextProfile == nil then
		warn(string.format("[CHESS_SHOP] buy failed reason=%s", tostring(reason)))
		publish(player, nil)
		return
	end
	profileStore:set(player.UserId, nextProfile)
	profileStore:save(player.UserId)
	print(
		string.format(
			"[CHESS_SHOP] userId=%d bought=%s currency=%d roster=%d",
			player.UserId,
			pieceType,
			nextProfile.currency,
			#nextProfile.roster
		)
	)
	publish(player, nil)
end)

requestBuyUpgrade.OnServerEvent:Connect(function(player, ...)
	local packed = table.pack(...)
	local snapshot = controller:snapshot(player.UserId)
	local phase = if snapshot ~= nil then snapshot.phase else "Lobby"
	local validated = guard:validateBuy(player.UserId, {
		argc = select("#", ...),
		args = packed,
	}, { phase = phase })
	if not validated.accepted then
		warn(
			string.format("[CHESS_SECURITY] rejected RequestBuyUpgrade reason=%s", validated.reason)
		)
		return
	end
	local upgradeName = packed[1]
	local profile = profileStore:get(player.UserId)
	if profile == nil then
		return
	end
	local okBuy, nextProfile, reason = ProfileRules.buyUpgrade(profile, upgradeName, Config)
	if not okBuy or nextProfile == nil then
		warn(string.format("[CHESS_SHOP] upgrade failed reason=%s", tostring(reason)))
		publish(player, nil)
		return
	end
	profileStore:set(player.UserId, nextProfile)
	profileStore:save(player.UserId)
	print(
		string.format(
			"[CHESS_SHOP] userId=%d upgrade=%s level=%d currency=%d",
			player.UserId,
			upgradeName,
			nextProfile.upgrades[upgradeName],
			nextProfile.currency
		)
	)
	publish(player, nil)
end)

requestTranscend.OnServerEvent:Connect(function(player, ...)
	local packed = table.pack(...)
	local snapshot = controller:snapshot(player.UserId)
	local phase = if snapshot ~= nil then snapshot.phase else "NoRun"
	local validated = guard:validateTranscend(player.UserId, {
		argc = select("#", ...),
		args = packed,
	}, { phase = phase })
	if not validated.accepted then
		warn(
			string.format("[CHESS_SECURITY] rejected RequestTranscend reason=%s", validated.reason)
		)
		return
	end
	local profile = profileStore:get(player.UserId)
	if profile == nil then
		return
	end
	local nextProfile = ProfileRules.transcend(profile)
	profileStore:set(player.UserId, nextProfile)
	profileStore:save(player.UserId)
	print(
		string.format(
			"[CHESS_TRANSCEND] userId=%d T=%d",
			player.UserId,
			nextProfile.transcendenceLevel
		)
	)
	-- Start a new run immediately at the higher transcendence.
	pendingLoss[player.UserId] = false
	settled[player.UserId] = false
	local started = ProfileRules.recordRunStart(nextProfile)
	profileStore:set(player.UserId, started)
	local metrics = sessionMetrics[player.UserId]
	if metrics ~= nil then
		metrics:recordRunStart()
	end
	controller:start(player.UserId, started.roster, runOptions(started))
	lastResults[player.UserId] = nil
	publish(player, nil)
end)

Players.PlayerAdded:Connect(function(player)
	local ok, _profile, err = profileStore:load(player.UserId)
	if not ok then
		warn("[CHESS_PROFILE] load failed: " .. tostring(err))
		local _, fallback = ProfileRules.normalize(nil, Config)
		profileStore._sessions[player.UserId] = { profile = fallback, dirty = true }
	end
	sessionMetrics[player.UserId] = Metrics.new(os.clock)
	startRun(player)
end)

Players.PlayerRemoving:Connect(function(player)
	profileStore:release(player.UserId)
	controller:clear(player.UserId)
	sessionMetrics[player.UserId] = nil
	lastResults[player.UserId] = nil
	pendingLoss[player.UserId] = nil
	settled[player.UserId] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	local ok, _, err = profileStore:load(player.UserId)
	if not ok then
		warn("[CHESS_PROFILE] load failed: " .. tostring(err))
		local _, fallback = ProfileRules.normalize(nil, Config)
		profileStore._sessions[player.UserId] = { profile = fallback, dirty = true }
	end
	sessionMetrics[player.UserId] = Metrics.new(os.clock)
	startRun(player)
end

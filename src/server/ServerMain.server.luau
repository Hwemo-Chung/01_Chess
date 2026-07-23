local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunController = require(script.Parent.RunController)
local RemoteGuard = require(script.Parent.RemoteGuard)
local EnemyAI = require(script.Parent.EnemyAI)

local Shared = ReplicatedStorage:WaitForChild("Chess"):WaitForChild("Shared")
local RunState = require(Shared:WaitForChild("RunState"))
local Config = require(Shared:WaitForChild("Config"))

local MVP_ROSTER = { "Pawn", "Knight", "Rook" }

local controller = RunController.new({
	clock = os.clock,
	seedForPlayer = function(userId)
		-- Mix wall clock so restarts don't replay the same seed forever.
		return (userId * 10007 + math.floor(os.clock() * 1000)) % 2147483646 + 1
	end,
	RunState = RunState,
	Config = Config,
})
local guard = RemoteGuard.new(os.clock)

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
local stateSync = ensureRemoteEvent(remotes, "StateSync")

local lastResults: { [number]: any } = {}

local function applyEnemyTurn(playerUserId: number)
	local state = controller.runs[playerUserId]
	if state == nil or state.activePiece == nil or state.runOver then
		return
	end
	local destinations = EnemyAI.planMoves(state.enemies, state.activePosition, Config.BOARD_SIZE)
	for index, destination in ipairs(destinations) do
		local enemy = state.enemies[index]
		if enemy ~= nil then
			enemy.x = destination.x
			enemy.z = destination.z
		end
	end
end

local function publish(player, lastResult: any?)
	local snapshot = controller:snapshot(player.UserId)
	if snapshot == nil then
		return
	end
	if lastResult ~= nil then
		lastResults[player.UserId] = lastResult
	end
	snapshot.lastResult = lastResults[player.UserId]

	player:SetAttribute("ActivePiece", snapshot.activePiece)
	player:SetAttribute("ActiveHealth", snapshot.activeHealth)
	player:SetAttribute("ActiveMaxHealth", snapshot.activeMaxHealth)
	player:SetAttribute("Level", snapshot.level)
	player:SetAttribute("PositionX", snapshot.activePosition.x)
	player:SetAttribute("PositionZ", snapshot.activePosition.z)
	player:SetAttribute("RosterCount", #snapshot.roster)
	player:SetAttribute("EnemyCount", #snapshot.enemies)
	player:SetAttribute("Invulnerable", snapshot.invulnerable)
	player:SetAttribute("RunOver", snapshot.runOver)
	player:SetAttribute("RerollsRemaining", snapshot.rerollsRemaining)
	player:SetAttribute("Phase", snapshot.phase)

	stateSync:FireClient(player, snapshot)
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
		if moveResult ~= nil and not moveResult.runOver then
			applyEnemyTurn(player.UserId)
		end
	end)
	if not ok then
		warn(string.format("[CHESS_SECURITY] SubmitMove failed: %s", tostring(err)))
		return
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
	controller:restart(player.UserId, MVP_ROSTER)
	lastResults[player.UserId] = nil
	publish(player, nil)
end)

Players.PlayerAdded:Connect(function(player)
	controller:start(player.UserId, MVP_ROSTER)
	lastResults[player.UserId] = nil
	publish(player, nil)
end)

Players.PlayerRemoving:Connect(function(player)
	controller.runs[player.UserId] = nil
	lastResults[player.UserId] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	controller:start(player.UserId, MVP_ROSTER)
	lastResults[player.UserId] = nil
	publish(player, nil)
end

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
		return userId
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

local function applyEnemyTurn(playerUserId: number)
	local state = controller.runs[playerUserId]
	if state == nil or state.activePiece == nil then
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

local function publish(player)
	local snapshot = controller:snapshot(player.UserId)
	if snapshot == nil then
		return
	end
	player:SetAttribute("ActivePiece", snapshot.activePiece)
	player:SetAttribute("ActiveHealth", snapshot.activeHealth)
	player:SetAttribute("ActiveMaxHealth", snapshot.activeMaxHealth)
	player:SetAttribute("Level", snapshot.level)
	player:SetAttribute("PositionX", snapshot.activePosition.x)
	player:SetAttribute("PositionZ", snapshot.activePosition.z)
	player:SetAttribute("RosterCount", #snapshot.roster)
	player:SetAttribute("EnemyCount", #snapshot.enemies)
	player:SetAttribute("Invulnerable", snapshot.invulnerable)
end

submitMove.OnServerEvent:Connect(function(player, ...)
	local packed = table.pack(...)
	local snapshot = controller:snapshot(player.UserId)
	local validated = guard:validateMove(player.UserId, {
		argc = select("#", ...),
		args = packed,
	}, { phase = snapshot ~= nil and "Turn" or "NoRun" })
	if not validated.accepted then
		warn(string.format("[CHESS_SECURITY] rejected SubmitMove reason=%s", validated.reason))
		return
	end
	local ok, err = pcall(function()
		local result = controller:submitMove(player.UserId, packed[1], packed[2])
		-- Enemy turn is movement-only (PRD §6.1); skip if the run ended.
		if not result.runOver then
			applyEnemyTurn(player.UserId)
		end
	end)
	if not ok then
		warn(string.format("[CHESS_SECURITY] SubmitMove failed: %s", tostring(err)))
		return
	end
	publish(player)
end)

requestReroll.OnServerEvent:Connect(function(player, ...)
	local packed = table.pack(...)
	local snapshot = controller:snapshot(player.UserId)
	local validated = guard:validateReroll(player.UserId, {
		argc = select("#", ...),
		args = packed,
	}, { phase = snapshot ~= nil and "Turn" or "NoRun" })
	if not validated.accepted then
		warn(string.format("[CHESS_SECURITY] rejected RequestReroll reason=%s", validated.reason))
		return
	end
	controller:requestReroll(player.UserId)
	publish(player)
end)

Players.PlayerAdded:Connect(function(player)
	controller:start(player.UserId, MVP_ROSTER)
	publish(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	controller:start(player.UserId, MVP_ROSTER)
	publish(player)
end

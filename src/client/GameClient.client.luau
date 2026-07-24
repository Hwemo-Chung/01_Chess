-- Client composition: board + HUD + camera, server StateSync only for truth.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

print("[CHESS] GameClient starting…")

local BoardView = require(script.Parent:WaitForChild("BoardView"))
local CameraController = require(script.Parent:WaitForChild("CameraController"))
local HudController = require(script.Parent:WaitForChild("HudController"))

local player = Players.LocalPlayer
local board = BoardView.new()
local camera = CameraController.new(player)
local hud = HudController.new(player)

local latestSnapshot = nil
local cleaned = false

local function remotesFolder()
	local chess = ReplicatedStorage:WaitForChild("Chess", 30)
	if chess == nil then
		warn("[CHESS] ReplicatedStorage.Chess missing")
		return nil
	end
	return chess:WaitForChild("Remotes", 30)
end

local function remote(name: string): RemoteEvent?
	local folder = remotesFolder()
	if folder == nil then
		return nil
	end
	local value = folder:FindFirstChild(name)
	if value ~= nil and value:IsA("RemoteEvent") then
		return value
	end
	local waited = folder:WaitForChild(name, 15)
	if waited ~= nil and waited:IsA("RemoteEvent") then
		return waited
	end
	return nil
end

local function applySnapshot(snapshot)
	if type(snapshot) ~= "table" then
		return
	end
	latestSnapshot = snapshot
	board:render(snapshot)
	hud:render(snapshot)
	camera:apply()
	print(
		string.format(
			"[CHESS] snapshot phase=%s piece=%s enemies=%s",
			tostring(snapshot.phase),
			tostring(snapshot.activePiece),
			tostring(snapshot.enemies and #snapshot.enemies)
		)
	)
end

local function isLegalMove(x: number, z: number): boolean
	if latestSnapshot == nil or type(latestSnapshot.legalMoves) ~= "table" then
		return false
	end
	for _, move in ipairs(latestSnapshot.legalMoves) do
		if move.x == x and move.z == z then
			return true
		end
	end
	return false
end

board:onTileClick(function(x, z)
	if latestSnapshot == nil or latestSnapshot.runOver then
		return
	end
	if not isLegalMove(x, z) then
		return
	end
	local submit = remote("SubmitMove")
	if submit ~= nil then
		submit:FireServer(x, z)
	end
end)

hud:onReroll(function()
	if latestSnapshot == nil or latestSnapshot.runOver then
		return
	end
	if (latestSnapshot.rerollsRemaining or 0) <= 0 then
		return
	end
	local request = remote("RequestReroll")
	if request ~= nil then
		request:FireServer()
	end
end)

hud:onRestart(function()
	if latestSnapshot == nil or not latestSnapshot.runOver then
		return
	end
	local request = remote("RequestRestart")
	if request ~= nil then
		request:FireServer()
	end
end)

hud:onBuy(function(pieceType)
	local request = remote("RequestBuy")
	if request ~= nil then
		request:FireServer(pieceType)
	end
end)

hud:onBuyUpgrade(function(upgradeId)
	local request = remote("RequestBuyUpgrade")
	if request ~= nil then
		request:FireServer(upgradeId)
	end
end)

hud:onTranscend(function()
	if
		latestSnapshot == nil or not (latestSnapshot.victory or latestSnapshot.phase == "Victory")
	then
		return
	end
	local request = remote("RequestTranscend")
	if request ~= nil then
		request:FireServer()
	end
end)

-- Wire StateSync BEFORE requesting a snapshot (critical race fix).
local stateSync = remote("StateSync")
if stateSync ~= nil then
	stateSync.OnClientEvent:Connect(applySnapshot)
	print("[CHESS] StateSync connected")
else
	warn("[CHESS] StateSync remote missing — board will stay empty")
end

local function askServerForState()
	local req = remote("RequestStateSync")
	if req ~= nil then
		req:FireServer()
	end
end

askServerForState()
task.spawn(function()
	for _ = 1, 10 do
		if latestSnapshot ~= nil and latestSnapshot.activePiece ~= nil then
			return
		end
		task.wait(0.4)
		askServerForState()
		camera:apply()
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if
		input.UserInputType ~= Enum.UserInputType.MouseButton1
		and input.UserInputType ~= Enum.UserInputType.Touch
	then
		return
	end
	local cameraObj = Workspace.CurrentCamera
	if cameraObj == nil then
		return
	end
	local position = input.Position
	local ray = cameraObj:ViewportPointToRay(position.X, position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = {}
	if player.Character ~= nil then
		table.insert(exclude, player.Character)
	end
	params.FilterDescendantsInstances = exclude
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	if result == nil then
		return
	end
	board:handleClickPosition(result.Position)
end)

local function hideCharacter(character: Model)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = 1
			descendant.CanCollide = false
		end
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	end
	-- Character spawn resets camera — reclaim top-down view.
	task.defer(function()
		camera:apply()
	end)
end

if player.Character ~= nil then
	hideCharacter(player.Character)
end
player.CharacterAdded:Connect(hideCharacter)

local function cleanup()
	if cleaned then
		return
	end
	cleaned = true
	board:destroy()
	camera:destroy()
	hud:destroy()
end

script.Destroying:Connect(cleanup)
print("[CHESS] GameClient ready")

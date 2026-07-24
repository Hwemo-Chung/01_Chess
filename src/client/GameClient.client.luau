-- Client composition: board + HUD + camera, server StateSync only for truth.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local BoardView = require(script.Parent.BoardView)
local CameraController = require(script.Parent.CameraController)
local HudController = require(script.Parent.HudController)

local player = Players.LocalPlayer
local board = BoardView.new()
local camera = CameraController.new(player)
local hud = HudController.new(player)

local latestSnapshot = nil
local cleaned = false

local function remotesFolder()
	local chess = ReplicatedStorage:WaitForChild("Chess", 10)
	if chess == nil then
		return nil
	end
	return chess:WaitForChild("Remotes", 10)
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
	return folder:WaitForChild(name, 5) :: RemoteEvent?
end

local function applySnapshot(snapshot)
	if type(snapshot) ~= "table" then
		return
	end
	latestSnapshot = snapshot
	board:render(snapshot)
	hud:render(snapshot)
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

local stateSync = remote("StateSync")
if stateSync ~= nil then
	stateSync.OnClientEvent:Connect(applySnapshot)
end

-- Click → raycast board plane / tiles
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
	params.FilterDescendantsInstances = { player.Character }
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	if result == nil then
		return
	end
	board:handleClickPosition(result.Position)
end)

-- Hide default character so it doesn't clutter the board view.
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

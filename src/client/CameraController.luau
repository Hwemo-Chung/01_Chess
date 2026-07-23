-- Top-down fixed camera aimed at the chess board center.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Chess"):WaitForChild("Shared")
local BoardLayout = require(Shared:WaitForChild("BoardLayout"))

local CameraController = {}
CameraController.__index = CameraController

function CameraController.new(player: Player)
	local camera = Workspace.CurrentCamera
	local self = setmetatable({
		_player = player,
		_camera = camera,
		_connection = nil :: RBXScriptConnection?,
	}, CameraController)
	self:apply()
	self._connection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self._camera = Workspace.CurrentCamera
		self:apply()
	end)
	return self
end

function CameraController.apply(self)
	local camera = self._camera
	if camera == nil then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local extent = BoardLayout.boardExtent()
	local height = extent * 1.35
	local centerX, _, centerZ = BoardLayout.boardCenter()
	camera.CFrame = CFrame.new(
		Vector3.new(centerX, height, centerZ + extent * 0.15),
		Vector3.new(centerX, 0, centerZ)
	)
	camera.FieldOfView = 40
end

function CameraController.destroy(self)
	if self._connection ~= nil then
		self._connection:Disconnect()
		self._connection = nil
	end
	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		camera.CameraType = Enum.CameraType.Custom
	end
end

return CameraController

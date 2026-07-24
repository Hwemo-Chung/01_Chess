-- Client ImageLabel helpers keyed by IconAssets names.
-- Priority: cloud/asphalt URI → EditableImage pixels → no icon (text fallback).
-- TextButton never replaced (PRD §4.2). Active=false for click-through.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IconSurface = require(script.Parent:WaitForChild("IconSurface"))
local Shared = ReplicatedStorage:WaitForChild("Chess"):WaitForChild("Shared")
local IconAssets = require(Shared:WaitForChild("IconAssets"))

local AssetUi = {}

local function create(className: string, props)
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		(instance :: any)[key] = value
	end
	return instance
end

function AssetUi.setLeftPad(guiObject: GuiObject, pixels: number)
	local padding = guiObject:FindFirstChildOfClass("UIPadding")
	if pixels <= 0 then
		if padding ~= nil then
			padding:Destroy()
		end
		return
	end
	if padding == nil then
		padding = Instance.new("UIPadding")
		padding.Parent = guiObject
	end
	padding.PaddingLeft = UDim.new(0, pixels)
	padding.PaddingRight = UDim.new(0, 0)
	padding.PaddingTop = UDim.new(0, 0)
	padding.PaddingBottom = UDim.new(0, 0)
end

-- Create/update child ImageLabel for logical icon key. Returns label or nil.
function AssetUi.setIcon(
	parent: GuiObject,
	name: string,
	key: string?,
	size: number,
	position: UDim2
): ImageLabel?
	local existing = parent:FindFirstChild(name)
	if type(key) ~= "string" or key == "" or not IconSurface.has(key) then
		if existing ~= nil then
			existing:Destroy()
		end
		return nil
	end

	local icon: ImageLabel
	if existing ~= nil and existing:IsA("ImageLabel") then
		icon = existing
	else
		if existing ~= nil then
			existing:Destroy()
		end
		icon = create("ImageLabel", {
			Name = name,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScaleType = Enum.ScaleType.Fit,
			Active = false,
			Parent = parent,
		})
	end
	icon.Size = UDim2.fromOffset(size, size)
	icon.Position = position
	icon.Visible = true
	icon.Active = false
	if not IconSurface.apply(icon, key) then
		icon:Destroy()
		return nil
	end
	return icon
end

function AssetUi.decorateButton(button: GuiButton, key: string?, size: number?): ImageLabel?
	local iconSize = size or 24
	local margin = 6
	local height = if button.Size.Y.Offset > 0 then button.Size.Y.Offset else 32
	local y = math.max(0, math.floor((height - iconSize) / 2))
	local icon = AssetUi.setIcon(button, "AssetIcon", key, iconSize, UDim2.fromOffset(margin, y))
	if icon ~= nil then
		AssetUi.setLeftPad(button, iconSize + margin * 2)
		if button:IsA("TextButton") then
			button.TextXAlignment = Enum.TextXAlignment.Left
		end
	else
		AssetUi.setLeftPad(button, 0)
	end
	return icon
end

function AssetUi.decorateLabel(label: TextLabel, key: string?, size: number?): ImageLabel?
	local iconSize = size or 18
	local icon = AssetUi.setIcon(label, "AssetIcon", key, iconSize, UDim2.fromOffset(0, 1))
	AssetUi.setLeftPad(label, if icon ~= nil then iconSize + 4 else 0)
	return icon
end

function AssetUi.pieceBlueKey(pieceName: string): string?
	return IconAssets.pieceKey(pieceName, "blue")
end

function AssetUi.pieceRedKey(pieceName: string): string?
	return IconAssets.pieceKey(pieceName, "red")
end

function AssetUi.upgradeKey(name: string): string?
	return IconAssets.upgradeKey(name)
end

function AssetUi.bossKey(): string
	return IconAssets.bossKey()
end

return AssetUi

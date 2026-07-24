-- Client-only: ImageLabel content from IconAssets URI or embedded IconPixels.
-- Priority: cloud/asphalt URI → EditableImage pixels → nil (text fallback).

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Chess"):WaitForChild("Shared")
local IconAssets = require(Shared:WaitForChild("IconAssets"))
local IconPixels = require(Shared:WaitForChild("IconPixels"))

local IconSurface = {}
local contentCache: { [string]: any } = {}
local editableFailed = false

local function contentFromPixels(key: string): any
	if editableFailed or type(IconPixels.rgbaBuffer) ~= "function" then
		return nil
	end
	local rgba = IconPixels.rgbaBuffer(key)
	if rgba == nil then
		return nil
	end
	local w, h = IconPixels.size()
	if w < 1 or h < 1 then
		return nil
	end
	local ok, content = pcall(function()
		local editable = AssetService:CreateEditableImage({
			Size = Vector2.new(w, h),
		})
		editable:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), rgba)
		return Content.fromObject(editable)
	end)
	if not ok then
		editableFailed = true
		return nil
	end
	return content
end

-- { kind = "uri", value = string } | { kind = "content", value = Content } | nil
function IconSurface.resolve(key: string): any
	if type(key) ~= "string" or #key == 0 then
		return nil
	end
	if contentCache[key] ~= nil then
		return contentCache[key]
	end
	local uri = IconAssets.image(key)
	if type(uri) == "string" and #uri > 0 then
		local resolved = { kind = "uri", value = uri }
		contentCache[key] = resolved
		return resolved
	end
	local content = contentFromPixels(key)
	if content ~= nil then
		local resolved = { kind = "content", value = content }
		contentCache[key] = resolved
		return resolved
	end
	return nil
end

function IconSurface.apply(imageLabel: ImageLabel, key: string): boolean
	if imageLabel == nil or not imageLabel:IsA("ImageLabel") then
		return false
	end
	local resolved = IconSurface.resolve(key)
	if resolved == nil then
		return false
	end
	if resolved.kind == "uri" then
		imageLabel.Image = resolved.value
		pcall(function()
			(imageLabel :: any).ImageContent = Content.none
		end)
		return true
	end
	if resolved.kind == "content" then
		imageLabel.Image = ""
		local ok = pcall(function()
			(imageLabel :: any).ImageContent = resolved.value
		end)
		return ok
	end
	return false
end

-- Cheap presence check (no EditableImage alloc). apply() may still fail on pixels.
function IconSurface.has(key: string): boolean
	if type(key) ~= "string" or #key == 0 then
		return false
	end
	local uri = IconAssets.image(key)
	if type(uri) == "string" and #uri > 0 then
		return true
	end
	return IconPixels.has(key)
end

return IconSurface

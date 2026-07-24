-- Pure pixel decode for embedded HUD icons (IconPixelPack).
-- No rbxassetid; used when IconAssets.image is nil (cloud 0 + no asphalt URI).

local function requirePack()
	-- Roblox engine rejects string requires; Lune (tests) has no `script` global.
	local ok, mod = pcall(function()
		if script ~= nil then
			return require(script.Parent:FindFirstChild("IconPixelPack")) :: any
		end
		return require("./IconPixelPack")
	end)
	if ok then
		return mod
	end
	return {
		width = 0,
		height = 0,
		entries = {},
	}
end

local IconPixelPack = requirePack()

local IconPixels = {}

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local DECODE = {}
for index = 1, #ALPHABET do
	DECODE[string.byte(ALPHABET, index)] = index - 1
end

local function base64Decode(data: string): buffer?
	if type(data) ~= "string" or #data == 0 then
		return nil
	end
	data = string.gsub(data, "%s+", "")
	local padding = 0
	if string.sub(data, -2) == "==" then
		padding = 2
	elseif string.sub(data, -1) == "=" then
		padding = 1
	end
	local outLen = math.floor(#data / 4) * 3 - padding
	if outLen < 1 then
		return nil
	end
	local out = buffer.create(outLen)
	local o = 0
	for i = 1, #data, 4 do
		local c1 = DECODE[string.byte(data, i)] or 0
		local c2 = DECODE[string.byte(data, i + 1)] or 0
		local c3 = DECODE[string.byte(data, i + 2)] or 0
		local c4 = DECODE[string.byte(data, i + 3)] or 0
		local n = bit32.lshift(c1, 18) + bit32.lshift(c2, 12) + bit32.lshift(c3, 6) + c4
		if o < outLen then
			buffer.writeu8(out, o, bit32.band(bit32.rshift(n, 16), 255))
			o += 1
		end
		if o < outLen then
			buffer.writeu8(out, o, bit32.band(bit32.rshift(n, 8), 255))
			o += 1
		end
		if o < outLen then
			buffer.writeu8(out, o, bit32.band(n, 255))
			o += 1
		end
	end
	return out
end

function IconPixels.size(): (number, number)
	local w = IconPixelPack.width
	local h = IconPixelPack.height
	if type(w) ~= "number" or type(h) ~= "number" then
		return 0, 0
	end
	return math.floor(w), math.floor(h)
end

function IconPixels.has(key: string): boolean
	local entries = IconPixelPack.entries
	return type(entries) == "table" and type(entries[key]) == "string" and #entries[key] > 0
end

function IconPixels.rgbaBuffer(key: string): buffer?
	if not IconPixels.has(key) then
		return nil
	end
	local raw = base64Decode(IconPixelPack.entries[key])
	if raw == nil then
		return nil
	end
	local w, h = IconPixels.size()
	local expected = w * h * 4
	if expected > 0 and buffer.len(raw) ~= expected then
		return nil
	end
	return raw
end

return IconPixels

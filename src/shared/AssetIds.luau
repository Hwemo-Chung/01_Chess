-- Pure asset resolution for Config.ASSET_IDS + optional GeneratedAssets.
-- Priority: numeric cloud id (rbxassetid://) → GeneratedAssets studio URI → nil (text fallback).
-- No Roblox Instance APIs — safe for Lune unit tests.

local AssetIds = {}

local generatedCache: any = nil
local generatedTried = false

local function loadGenerated(): any
	if generatedTried then
		return generatedCache
	end
	generatedTried = true
	local ok, mod = pcall(function()
		return require("./GeneratedAssets")
	end)
	if ok and type(mod) == "table" then
		generatedCache = mod
	else
		generatedCache = nil
	end
	return generatedCache
end

function AssetIds.isValidCloudId(id: any): boolean
	return type(id) == "number" and id > 0 and id == id and id ~= math.huge
end

function AssetIds.isUri(value: any): boolean
	return type(value) == "string"
		and (
			string.sub(value, 1, 11) == "rbxasset://"
			or string.sub(value, 1, 13) == "rbxassetid://"
		)
end

-- Accept cloud number, full URI string, or reject.
function AssetIds.imageUri(id: any): string?
	if AssetIds.isUri(id) then
		return id
	end
	if AssetIds.isValidCloudId(id) then
		return "rbxassetid://" .. tostring(math.floor(id))
	end
	return nil
end

-- Back-compat alias used by older call sites / tests.
function AssetIds.isValidId(id: any): boolean
	return AssetIds.isValidCloudId(id) or AssetIds.isUri(id)
end

function AssetIds.table(config: any): any
	if type(config) ~= "table" then
		return nil
	end
	local ids = config.ASSET_IDS
	if type(ids) ~= "table" then
		return nil
	end
	return ids
end

local function fromGenerated(key: string): string?
	local gen = loadGenerated()
	if gen == nil then
		return nil
	end
	local value = gen[key]
	if AssetIds.isUri(value) then
		return value
	end
	return nil
end

function AssetIds.icon(config: any, key: string): string?
	local ids = AssetIds.table(config)
	if ids ~= nil and type(ids.icons) == "table" then
		local uri = AssetIds.imageUri(ids.icons[key])
		if uri ~= nil then
			return uri
		end
	end
	return fromGenerated("icon_" .. key)
end

function AssetIds.upgrade(config: any, name: string): string?
	local ids = AssetIds.table(config)
	if ids ~= nil and type(ids.upgrades) == "table" then
		local uri = AssetIds.imageUri(ids.upgrades[name])
		if uri ~= nil then
			return uri
		end
	end
	-- Generated keys: upgrade_might / upgrade_vitality
	local slug = string.lower(name)
	return fromGenerated("upgrade_" .. slug)
end

function AssetIds.boss(config: any, key: string?): string?
	local bossKey = key or "king"
	local ids = AssetIds.table(config)
	if ids ~= nil and type(ids.boss) == "table" then
		local uri = AssetIds.imageUri(ids.boss[bossKey])
		if uri ~= nil then
			return uri
		end
	end
	return fromGenerated("boss_" .. bossKey)
end

-- color: "blue" | "red"
function AssetIds.piece(config: any, pieceName: string, color: string): string?
	local ids = AssetIds.table(config)
	if ids ~= nil and type(ids.pieces) == "table" then
		local entry = ids.pieces[pieceName]
		if type(entry) == "table" then
			local uri = AssetIds.imageUri(entry[color])
			if uri ~= nil then
				return uri
			end
		end
	end
	local slug = "piece_" .. string.lower(pieceName) .. "_" .. color
	return fromGenerated(slug)
end

function AssetIds.bossLevel(config: any): number
	local cap = 12
	local order = { "Pawn", "Knight", "Bishop", "Rook", "Queen", "King" }
	if type(config) == "table" then
		if type(config.ENEMY_COUNT_CAP) == "number" then
			cap = config.ENEMY_COUNT_CAP
		end
		if type(config.ENEMY_TIER_ORDER) == "table" and #config.ENEMY_TIER_ORDER > 0 then
			order = config.ENEMY_TIER_ORDER
		end
	end
	local kingIndex = #order
	for index, name in ipairs(order) do
		if name == "King" then
			kingIndex = index
			break
		end
	end
	return cap + kingIndex - 1
end

return AssetIds

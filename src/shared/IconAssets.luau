-- Single source of truth for icon keys ↔ cloud ids ↔ disk paths ↔ generated names.
-- Cloud id 0 → try GeneratedAssets (asphalt studio) → IconPixels embed (IconSurface).
-- Asset IDs live ONLY here for cloud numbers (audit-assets allowlist).

local AssetIds = require("./AssetIds")

-- Cloud rbxassetid numbers. 0 = not uploaded.
local CLOUD = {
	Hp = 0,
	Atk = 0,
	Gold = 0,
	Level = 0,
	Crit = 0,
	Reroll = 0,
	Restart = 0,
	Transcend = 0,
	UpgradeMight = 0,
	UpgradeVitality = 0,
	BossKing = 0,
	PiecePawnBlue = 0,
	PieceKnightBlue = 0,
	PieceBishopBlue = 0,
	PieceRookBlue = 0,
	PieceQueenBlue = 0,
	PieceKingBlue = 0,
	PiecePawnRed = 0,
	PieceKnightRed = 0,
	PieceBishopRed = 0,
	PieceRookRed = 0,
	PieceQueenRed = 0,
	PieceKingRed = 0,
}

-- Repo-relative PNG paths (upload guide + existence tests).
local SOURCE_FILES = {
	Hp = "assets/images/icon_hp.png",
	Atk = "assets/images/icon_atk.png",
	Gold = "assets/images/icon_gold.png",
	Level = "assets/images/icon_level.png",
	Crit = "assets/images/icon_crit.png",
	Reroll = "assets/images/icon_reroll.png",
	Restart = "assets/images/icon_restart.png",
	Transcend = "assets/images/icon_transcend.png",
	UpgradeMight = "assets/images/upgrade_might.png",
	UpgradeVitality = "assets/images/upgrade_vitality.png",
	BossKing = "assets/images/boss_king.png",
	PiecePawnBlue = "assets/images/piece_pawn_blue.png",
	PieceKnightBlue = "assets/images/piece_knight_blue.png",
	PieceBishopBlue = "assets/images/piece_bishop_blue.png",
	PieceRookBlue = "assets/images/piece_rook_blue.png",
	PieceQueenBlue = "assets/images/piece_queen_blue.png",
	PieceKingBlue = "assets/images/piece_king_blue.png",
	PiecePawnRed = "assets/images/piece_pawn_red.png",
	PieceKnightRed = "assets/images/piece_knight_red.png",
	PieceBishopRed = "assets/images/piece_bishop_red.png",
	PieceRookRed = "assets/images/piece_rook_red.png",
	PieceQueenRed = "assets/images/piece_queen_red.png",
	PieceKingRed = "assets/images/piece_king_red.png",
}

-- GeneratedAssets.luau field names (asphalt sync studio).
local GENERATED_KEYS = {
	Hp = "icon_hp",
	Atk = "icon_atk",
	Gold = "icon_gold",
	Level = "icon_level",
	Crit = "icon_crit",
	Reroll = "icon_reroll",
	Restart = "icon_restart",
	Transcend = "icon_transcend",
	UpgradeMight = "upgrade_might",
	UpgradeVitality = "upgrade_vitality",
	BossKing = "boss_king",
	PiecePawnBlue = "piece_pawn_blue",
	PieceKnightBlue = "piece_knight_blue",
	PieceBishopBlue = "piece_bishop_blue",
	PieceRookBlue = "piece_rook_blue",
	PieceQueenBlue = "piece_queen_blue",
	PieceKingBlue = "piece_king_blue",
	PiecePawnRed = "piece_pawn_red",
	PieceKnightRed = "piece_knight_red",
	PieceBishopRed = "piece_bishop_red",
	PieceRookRed = "piece_rook_red",
	PieceQueenRed = "piece_queen_red",
	PieceKingRed = "piece_king_red",
}

local PIECE_BLUE = {
	Pawn = "PiecePawnBlue",
	Knight = "PieceKnightBlue",
	Bishop = "PieceBishopBlue",
	Rook = "PieceRookBlue",
	Queen = "PieceQueenBlue",
	King = "PieceKingBlue",
}

local PIECE_RED = {
	Pawn = "PiecePawnRed",
	Knight = "PieceKnightRed",
	Bishop = "PieceBishopRed",
	Rook = "PieceRookRed",
	Queen = "PieceQueenRed",
	King = "PieceKingRed",
}

local UPGRADE = {
	Might = "UpgradeMight",
	Vitality = "UpgradeVitality",
}

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

local IconAssets = {}

function IconAssets.imageUri(id: any): string?
	return AssetIds.imageUri(id)
end

function IconAssets.assetId(key: string): number
	local id = CLOUD[key]
	if AssetIds.isValidCloudId(id) then
		return math.floor(id)
	end
	return 0
end

function IconAssets.isConfigured(key: string): boolean
	return IconAssets.assetId(key) > 0
end

function IconAssets.sourceFile(key: string): string?
	return SOURCE_FILES[key]
end

function IconAssets.generatedKey(key: string): string?
	return GENERATED_KEYS[key]
end

-- URI string for ImageLabel.Image, or nil (then IconSurface tries pixels).
function IconAssets.image(key: string): string?
	if type(key) ~= "string" or #key == 0 then
		return nil
	end
	local cloud = IconAssets.imageUri(CLOUD[key])
	if cloud ~= nil then
		return cloud
	end
	local gName = GENERATED_KEYS[key]
	if gName == nil then
		return nil
	end
	local gen = loadGenerated()
	if gen == nil then
		return nil
	end
	local uri = gen[gName]
	if AssetIds.isUri(uri) then
		return uri
	end
	return nil
end

function IconAssets.keys(): { string }
	local list = {}
	for key in pairs(CLOUD) do
		table.insert(list, key)
	end
	table.sort(list)
	return list
end

function IconAssets.pieceKey(pieceName: string, color: string): string?
	local map = if color == "red" then PIECE_RED else PIECE_BLUE
	return map[pieceName]
end

function IconAssets.upgradeKey(name: string): string?
	return UPGRADE[name]
end

function IconAssets.bossKey(): string
	return "BossKing"
end

return IconAssets

-- AssetIds pure resolution tests (no Roblox Instances).
local AssetIds = require("../src/shared/AssetIds")

return function()
	local cases = 0
	local function check(name: string, cond: boolean)
		assert(cond, "FAIL AssetIds: " .. name)
		cases += 1
	end

	check("invalid 0", not AssetIds.isValidCloudId(0))
	check("invalid nil", not AssetIds.isValidCloudId(nil))
	check("invalid neg", not AssetIds.isValidCloudId(-1))
	check("valid cloud", AssetIds.isValidCloudId(12345))
	check("uri detects rbxasset", AssetIds.isUri("rbxasset://x.png"))
	check("uri detects rbxassetid", AssetIds.isUri("rbxassetid://9"))

	check("uri nil on 0", AssetIds.imageUri(0) == nil)
	check("uri format cloud", AssetIds.imageUri(99) == "rbxassetid://99")
	check("uri pass-through", AssetIds.imageUri("rbxasset://a.png") == "rbxasset://a.png")

	local empty = {}
	check("no table", AssetIds.table(empty) == nil)

	local cfg = {
		ENEMY_COUNT_CAP = 12,
		ENEMY_TIER_ORDER = { "Pawn", "Knight", "Bishop", "Rook", "Queen", "King" },
		ASSET_IDS = {
			pieces = {
				Pawn = { blue = 11, red = 21 },
				Knight = { blue = 0, red = 0 },
			},
			upgrades = { Might = 31, Vitality = 0 },
			icons = { hp = 41, atk = 0, gold = 42, crit = 43 },
			boss = { king = 51 },
		},
	}

	check("piece blue cloud", AssetIds.piece(cfg, "Pawn", "blue") == "rbxassetid://11")
	check("piece red cloud", AssetIds.piece(cfg, "Pawn", "red") == "rbxassetid://21")
	-- Knight 0 falls through to GeneratedAssets if present
	local knightBlue = AssetIds.piece(cfg, "Knight", "blue")
	check(
		"piece zero → generated or nil",
		knightBlue == nil or type(knightBlue) == "string"
	)
	check("upgrade ok", AssetIds.upgrade(cfg, "Might") == "rbxassetid://31")
	check("icon ok", AssetIds.icon(cfg, "hp") == "rbxassetid://41")
	check("boss ok", AssetIds.boss(cfg, "king") == "rbxassetid://51")
	check("boss level default", AssetIds.bossLevel(cfg) == 17)

	-- GeneratedAssets studio fallback when cloud id is 0
	local genHp = AssetIds.icon({ ASSET_IDS = { icons = { hp = 0 } } }, "hp")
	check(
		"generated hp when cloud 0",
		genHp ~= nil and string.sub(genHp :: string, 1, 11) == "rbxasset://"
	)
	local genPawn = AssetIds.piece({ ASSET_IDS = { pieces = {} } }, "Pawn", "blue")
	check(
		"generated piece_pawn_blue",
		genPawn ~= nil and string.find(genPawn :: string, "rbxasset://", 1, true) ~= nil
	)
	local genBoss = AssetIds.boss({}, "king")
	check(
		"generated boss_king",
		genBoss ~= nil and string.find(genBoss :: string, "rbxasset://", 1, true) ~= nil
	)

	local short = {
		ENEMY_COUNT_CAP = 10,
		ENEMY_TIER_ORDER = { "Pawn", "King" },
	}
	check("boss level short ladder", AssetIds.bossLevel(short) == 11)

	print(string.format("AssetIds: PASS (%d cases)", cases))
	return cases
end

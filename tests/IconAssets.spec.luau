-- IconAssets single-key API + IconPixels embed presence.
local fs = require("@lune/fs")
local IconAssets = require("../src/shared/IconAssets")
local IconPixels = require("../src/shared/IconPixels")

return function()
	local cases = 0
	local function check(name: string, cond: boolean)
		assert(cond, "FAIL IconAssets: " .. name)
		cases += 1
	end

	local keys = IconAssets.keys()
	check("keys non-empty", #keys >= 20)
	check("has Hp", table.find(keys, "Hp") ~= nil)
	check("has PiecePawnBlue", table.find(keys, "PiecePawnBlue") ~= nil)

	check("cloud default 0", IconAssets.assetId("Hp") == 0)
	check("not configured", IconAssets.isConfigured("Hp") == false)

	-- GeneratedAssets (asphalt) may provide URI while cloud is 0.
	local image = IconAssets.image("Hp")
	check(
		"image uri or nil",
		image == nil or type(image) == "string"
	)
	if type(image) == "string" then
		check(
			"image is rbxasset*",
			string.sub(image, 1, 11) == "rbxasset://" or string.sub(image, 1, 13) == "rbxassetid://"
		)
	end

	local src = IconAssets.sourceFile("Hp")
	check("sourceFile set", src == "assets/images/icon_hp.png")
	check("source exists on disk", fs.isFile(src :: string))

	for _, key in ipairs(keys) do
		local path = IconAssets.sourceFile(key)
		check("source " .. key, type(path) == "string" and fs.isFile(path :: string))
	end

	check("pieceKey blue", IconAssets.pieceKey("Pawn", "blue") == "PiecePawnBlue")
	check("pieceKey red", IconAssets.pieceKey("King", "red") == "PieceKingRed")
	check("upgradeKey", IconAssets.upgradeKey("Might") == "UpgradeMight")
	check("bossKey", IconAssets.bossKey() == "BossKing")

	-- Pixel pack
	check("pixels has Hp", IconPixels.has("Hp"))
	check("pixels has BossKing", IconPixels.has("BossKing"))
	local w, h = IconPixels.size()
	check("pixel size 64", w == 64 and h == 64)
	local buf = IconPixels.rgbaBuffer("Hp")
	check("rgba buffer", buf ~= nil and buffer.len(buf :: buffer) == 64 * 64 * 4)

	print(string.format("IconAssets: PASS (%d cases)", cases))
	return cases
end

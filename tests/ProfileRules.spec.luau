local ProfileRules = require("../src/shared/ProfileRules")
local Config = require("../src/shared/Config")

local cases = {}
local function case(name, body)
	table.insert(cases, { name = name, body = body })
end

case("default / starts with STARTING_ROSTER and zero currency", function()
	local profile = ProfileRules.default(Config)
	assert(#profile.roster == #Config.STARTING_ROSTER, "roster size")
	assert(profile.currency == 0, "currency")
end)

case("buy / spends currency and grows roster", function()
	local profile = ProfileRules.default(Config)
	profile.currency = 100
	local ok, nextProfile, reason = ProfileRules.buy(profile, "King", Config)
	assert(ok, "buy should succeed: " .. tostring(reason))
	assert(nextProfile.currency == 100 - Config.PIECES.King.price, "currency spent")
	assert(#nextProfile.roster == #Config.STARTING_ROSTER + 1, "roster grew")
	assert(nextProfile.roster[#nextProfile.roster] == "King", "King appended")
end)

case("buy / rejects insufficient currency", function()
	local profile = ProfileRules.default(Config)
	profile.currency = 0
	local ok, _, reason = ProfileRules.buy(profile, "Queen", Config)
	assert(not ok and reason == "insufficient_currency", "expected insufficient_currency")
end)

case("awardRunEnd / pays CURRENCY_PER_LEVEL * level", function()
	local profile = ProfileRules.default(Config)
	local nextProfile, payout = ProfileRules.awardRunEnd(profile, 4, 10, Config)
	assert(payout == 4 * Config.CURRENCY_PER_LEVEL, "payout")
	assert(nextProfile.currency == payout, "currency credited")
	assert(nextProfile.stats.runsEnded == 1, "runsEnded")
	assert(nextProfile.stats.bestLevel == 4, "bestLevel")
end)

case("restartAfterLossRate / divides restarts by ended runs", function()
	local profile = ProfileRules.default(Config)
	profile.stats.runsEnded = 4
	profile.stats.restartsAfterLoss = 2
	assert(ProfileRules.restartAfterLossRate(profile) == 0.5, "rate")
end)

case("buyUpgrade / spends and levels Might", function()
	local profile = ProfileRules.default(Config)
	profile.currency = 100
	local ok, nextProfile = ProfileRules.buyUpgrade(profile, "Might", Config)
	assert(ok, "upgrade buy")
	assert(nextProfile.upgrades.Might == 1, "level 1")
	assert(nextProfile.currency == 100 - Config.UPGRADES.Might.price, "spent")
end)

case("effectivePieceStats / applies Might and Vitality", function()
	local base = Config.PIECES.Pawn
	local stats = ProfileRules.effectivePieceStats(base, { Might = 2, Vitality = 2 }, Config)
	assert(stats.attack > base.attack, "attack up")
	assert(stats.maxHealth > base.maxHealth, "hp up")
end)

case("transcend / increments level and keeps roster", function()
	local profile = ProfileRules.default(Config)
	profile.roster = { "Pawn", "King" }
	local nextProfile = ProfileRules.transcend(profile)
	assert(nextProfile.transcendenceLevel == 2, "T2")
	assert(#nextProfile.roster == 2, "roster kept")
end)

return function()
	for _, entry in ipairs(cases) do
		local ok, err = pcall(entry.body)
		assert(ok, entry.name .. " FAILED: " .. tostring(err))
	end
	print(string.format("ProfileRules: PASS (%d cases)", #cases))
	return #cases
end

-- Pure profile / economy / upgrade / transcendence rules.
local ProfileRules = {}

export type Profile = {
	version: number,
	currency: number,
	roster: { string },
	upgrades: { [string]: number },
	transcendenceLevel: number,
	stats: {
		runsStarted: number,
		runsEnded: number,
		restartsAfterLoss: number,
		totalRounds: number,
		totalLevelsReached: number,
		bestLevel: number,
		victories: number,
		highestTranscendence: number,
	},
}

local function copyProfile(profile: Profile): Profile
	local next = table.clone(profile)
	next.stats = table.clone(profile.stats)
	next.roster = table.clone(profile.roster)
	next.upgrades = table.clone(profile.upgrades)
	return next
end

function ProfileRules.defaultUpgrades(config: any): { [string]: number }
	local upgrades = {}
	for name, _ in pairs(config.UPGRADES or {}) do
		upgrades[name] = 0
	end
	return upgrades
end

function ProfileRules.default(config: any): Profile
	local roster = {}
	for _, piece in ipairs(config.STARTING_ROSTER) do
		table.insert(roster, piece)
	end
	return {
		version = 1,
		currency = 0,
		roster = roster,
		upgrades = ProfileRules.defaultUpgrades(config),
		transcendenceLevel = config.DEFAULT_TRANSCENDENCE or 1,
		stats = {
			runsStarted = 0,
			runsEnded = 0,
			restartsAfterLoss = 0,
			totalRounds = 0,
			totalLevelsReached = 0,
			bestLevel = 0,
			victories = 0,
			highestTranscendence = config.DEFAULT_TRANSCENDENCE or 1,
		},
	}
end

function ProfileRules.normalize(raw: any, config: any): (string?, Profile?)
	if raw == nil then
		return "ok", ProfileRules.default(config)
	end
	if type(raw) ~= "table" then
		return "corrupt", nil
	end
	if raw.version ~= nil and raw.version ~= 1 then
		return "unsupported_version", nil
	end
	local profile = ProfileRules.default(config)
	if type(raw.currency) == "number" and raw.currency >= 0 then
		profile.currency = math.floor(raw.currency)
	end
	if type(raw.transcendenceLevel) == "number" and raw.transcendenceLevel >= 1 then
		profile.transcendenceLevel = math.floor(raw.transcendenceLevel)
	end
	if type(raw.roster) == "table" and #raw.roster > 0 then
		local roster = {}
		for _, piece in ipairs(raw.roster) do
			if type(piece) == "string" and config.PIECES[piece] ~= nil then
				table.insert(roster, piece)
			end
		end
		if #roster > 0 then
			profile.roster = roster
		end
	end
	if type(raw.upgrades) == "table" then
		for name, def in pairs(config.UPGRADES or {}) do
			local value = raw.upgrades[name]
			if type(value) == "number" and value >= 0 then
				profile.upgrades[name] = math.min(math.floor(value), def.maxLevel)
			end
		end
	end
	if type(raw.stats) == "table" then
		for key, _ in pairs(profile.stats) do
			local value = raw.stats[key]
			if type(value) == "number" and value >= 0 then
				profile.stats[key] = math.floor(value)
			end
		end
	end
	return "ok", profile
end

-- Apply permanent upgrades to a base piece stats table (pure).
function ProfileRules.effectivePieceStats(baseStats: any, upgrades: any, config: any): any
	local attackPercent = 0
	local healthPercent = 0
	local upgradeDefs = config.UPGRADES or {}
	local levels = upgrades or {}
	for name, def in pairs(upgradeDefs) do
		local level = levels[name] or 0
		if def.stat == "attackPercent" then
			attackPercent += def.perLevel * level
		elseif def.stat == "healthPercent" then
			healthPercent += def.perLevel * level
		end
	end
	return {
		maxHealth = math.max(1, math.floor(baseStats.maxHealth * (1 + healthPercent) + 0.5)),
		attack = math.max(1, math.floor(baseStats.attack * (1 + attackPercent) + 0.5)),
		critChance = baseStats.critChance,
		price = baseStats.price,
		incomingDamageMultiplier = baseStats.incomingDamageMultiplier or 1,
		critFromDistance = baseStats.critFromDistance,
	}
end

function ProfileRules.awardRunEnd(
	profile: Profile,
	levelReached: number,
	roundsPlayed: number,
	config: any,
	outcome: string?
): (Profile, number)
	local next = copyProfile(profile)
	local payout = math.max(0, levelReached) * config.CURRENCY_PER_LEVEL
	if outcome == "victory" then
		payout += config.VICTORY_BONUS or 0
		next.stats.victories += 1
	end
	next.currency += payout
	next.stats.runsEnded += 1
	next.stats.totalRounds += math.max(0, roundsPlayed)
	next.stats.totalLevelsReached += math.max(0, levelReached)
	if levelReached > next.stats.bestLevel then
		next.stats.bestLevel = levelReached
	end
	return next, payout
end

function ProfileRules.recordRunStart(profile: Profile): Profile
	local next = copyProfile(profile)
	next.stats.runsStarted += 1
	return next
end

function ProfileRules.recordRestartAfterLoss(profile: Profile): Profile
	local next = copyProfile(profile)
	next.stats.restartsAfterLoss += 1
	return next
end

function ProfileRules.canBuy(profile: Profile, pieceType: string, config: any): (boolean, string)
	local stats = config.PIECES[pieceType]
	if stats == nil then
		return false, "unknown_piece"
	end
	if profile.currency < stats.price then
		return false, "insufficient_currency"
	end
	return true, "ok"
end

function ProfileRules.buy(
	profile: Profile,
	pieceType: string,
	config: any
): (boolean, Profile?, string)
	local ok, reason = ProfileRules.canBuy(profile, pieceType, config)
	if not ok then
		return false, nil, reason
	end
	local next = copyProfile(profile)
	next.currency -= config.PIECES[pieceType].price
	table.insert(next.roster, pieceType)
	return true, next, "ok"
end

function ProfileRules.canBuyUpgrade(
	profile: Profile,
	upgradeName: string,
	config: any
): (boolean, string)
	local def = config.UPGRADES and config.UPGRADES[upgradeName]
	if def == nil then
		return false, "unknown_upgrade"
	end
	local level = profile.upgrades[upgradeName] or 0
	if level >= def.maxLevel then
		return false, "max_level"
	end
	if profile.currency < def.price then
		return false, "insufficient_currency"
	end
	return true, "ok"
end

function ProfileRules.buyUpgrade(
	profile: Profile,
	upgradeName: string,
	config: any
): (boolean, Profile?, string)
	local ok, reason = ProfileRules.canBuyUpgrade(profile, upgradeName, config)
	if not ok then
		return false, nil, reason
	end
	local next = copyProfile(profile)
	local def = config.UPGRADES[upgradeName]
	next.currency -= def.price
	next.upgrades[upgradeName] = (next.upgrades[upgradeName] or 0) + 1
	return true, next, "ok"
end

-- After victory: raise transcendence by 1 (roster + upgrades kept). PRD §6.5.
function ProfileRules.transcend(profile: Profile): Profile
	local next = copyProfile(profile)
	next.transcendenceLevel += 1
	if next.transcendenceLevel > next.stats.highestTranscendence then
		next.stats.highestTranscendence = next.transcendenceLevel
	end
	return next
end

function ProfileRules.restartAfterLossRate(profile: Profile): number
	if profile.stats.runsEnded <= 0 then
		return 0
	end
	return profile.stats.restartsAfterLoss / profile.stats.runsEnded
end

return ProfileRules

-- Pure profile / economy rules. No Roblox dependencies.
local ProfileRules = {}

export type Profile = {
	version: number,
	currency: number,
	roster: { string },
	stats: {
		runsStarted: number,
		runsEnded: number,
		restartsAfterLoss: number,
		totalRounds: number,
		totalLevelsReached: number,
		bestLevel: number,
	},
}

function ProfileRules.default(config: any): Profile
	local roster = {}
	for _, piece in ipairs(config.STARTING_ROSTER) do
		table.insert(roster, piece)
	end
	return {
		version = 1,
		currency = 0,
		roster = roster,
		stats = {
			runsStarted = 0,
			runsEnded = 0,
			restartsAfterLoss = 0,
			totalRounds = 0,
			totalLevelsReached = 0,
			bestLevel = 0,
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

function ProfileRules.awardRunEnd(
	profile: Profile,
	levelReached: number,
	roundsPlayed: number,
	config: any
): (Profile, number)
	local next = table.clone(profile)
	next.stats = table.clone(profile.stats)
	next.roster = table.clone(profile.roster)
	local payout = math.max(0, levelReached) * config.CURRENCY_PER_LEVEL
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
	local next = table.clone(profile)
	next.stats = table.clone(profile.stats)
	next.roster = table.clone(profile.roster)
	next.stats.runsStarted += 1
	return next
end

function ProfileRules.recordRestartAfterLoss(profile: Profile): Profile
	local next = table.clone(profile)
	next.stats = table.clone(profile.stats)
	next.roster = table.clone(profile.roster)
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
	local next = table.clone(profile)
	next.stats = table.clone(profile.stats)
	next.roster = table.clone(profile.roster)
	next.currency -= config.PIECES[pieceType].price
	table.insert(next.roster, pieceType)
	return true, next, "ok"
end

-- restart-after-loss rate among ended runs that restarted (0..1). [session-level
-- rate is computed client/server from restartsAfterLoss / runsEnded.]
function ProfileRules.restartAfterLossRate(profile: Profile): number
	if profile.stats.runsEnded <= 0 then
		return 0
	end
	return profile.stats.restartsAfterLoss / profile.stats.runsEnded
end

return ProfileRules

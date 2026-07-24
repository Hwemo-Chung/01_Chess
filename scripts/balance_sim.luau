-- Deterministic balance simulation (PRD §12). Pure Lune — no Roblox.
-- Usage:
--   lune run scripts/balance_sim.luau
--   lune run scripts/balance_sim.luau -- --runs 100 --max-rounds 400
local process = require("@lune/process")
local fs = require("@lune/fs")

local Config = require("../src/shared/Config")
local RunState = require("../src/shared/RunState")
local SimAI = require("../src/shared/SimAI")
local SimEnemy = require("../src/shared/SimEnemy")

local function parseArgs(args)
	local options = {
		runs = 80,
		maxRounds = 500,
		seedBase = 1000,
	}
	local i = 1
	while i <= #args do
		local a = args[i]
		if a == "--runs" then
			options.runs = tonumber(args[i + 1]) or options.runs
			i += 2
		elseif a == "--max-rounds" then
			options.maxRounds = tonumber(args[i + 1]) or options.maxRounds
			i += 2
		elseif a == "--seed" then
			options.seedBase = tonumber(args[i + 1]) or options.seedBase
			i += 2
		else
			i += 1
		end
	end
	return options
end

local function emptyStats()
	return {
		n = 0,
		wins = 0,
		losses = 0,
		timeouts = 0,
		sumLevel = 0,
		sumRounds = 0,
		sumFirstCombat = 0,
		firstCombatCount = 0,
		maxLevel = 0,
		levels = {},
	}
end

local function record(stats, outcome)
	stats.n += 1
	if outcome.victory then
		stats.wins += 1
	elseif outcome.timeout then
		stats.timeouts += 1
	else
		stats.losses += 1
	end
	stats.sumLevel += outcome.level
	stats.sumRounds += outcome.rounds
	if outcome.level > stats.maxLevel then
		stats.maxLevel = outcome.level
	end
	if outcome.firstCombatRound then
		stats.sumFirstCombat += outcome.firstCombatRound
		stats.firstCombatCount += 1
	end
	stats.levels[outcome.level] = (stats.levels[outcome.level] or 0) + 1
end

local function summarize(stats)
	local n = math.max(1, stats.n)
	return {
		n = stats.n,
		winRate = stats.wins / n,
		lossRate = stats.losses / n,
		timeoutRate = stats.timeouts / n,
		avgLevel = stats.sumLevel / n,
		avgRounds = stats.sumRounds / n,
		maxLevel = stats.maxLevel,
		avgFirstCombat = if stats.firstCombatCount > 0
			then stats.sumFirstCombat / stats.firstCombatCount
			else nil,
	}
end

local function runOne(roster, seed, config, options, maxRounds)
	local state = RunState.new(roster, seed, config, options)
	state:assignRandomPiece()
	local firstCombatRound = nil
	local safety = 0

	while not state.runOver and not state.victory and safety < maxRounds do
		safety += 1
		local move = SimAI.pickMove(state)
		if move == nil then
			break
		end
		local result = state:applyPlayerMove(move)
		if firstCombatRound == nil and result.playerDamageDealt > 0 then
			firstCombatRound = state.roundsPlayed
		end
		if result.victory or result.runOver then
			break
		end
		SimEnemy.applyTurn(state)
	end

	return {
		victory = state.victory == true,
		timeout = not state.victory and not state.runOver,
		level = state.level,
		rounds = state.roundsPlayed,
		firstCombatRound = firstCombatRound,
		tier = state.currentTier,
		transcendence = state.transcendenceLevel,
	}
end

local function rosterOf(piece: string, lives: number): { string }
	local roster = {}
	for _ = 1, lives do
		table.insert(roster, piece)
	end
	return roster
end

local function pct(x: number): string
	return string.format("%5.1f%%", x * 100)
end

local function num(x: number, digits: number?): string
	return string.format("%." .. tostring(digits or 1) .. "f", x)
end

local function runBatch(label, roster, simOptions, cli, config)
	local stats = emptyStats()
	for i = 1, cli.runs do
		local seed = cli.seedBase + i * 17 + #label * 31
		local outcome = runOne(roster, seed, config, simOptions, cli.maxRounds)
		record(stats, outcome)
	end
	local s = summarize(stats)
	s.label = label
	return s, stats
end

local cli = parseArgs(process.args)
local config = Config
local lives = 3

print("=== 01_Chess Balance Sim ===")
print(
	string.format(
		"runs/scenario=%d  maxRounds=%d  lives=%d  seedBase=%d",
		cli.runs,
		cli.maxRounds,
		lives,
		cli.seedBase
	)
)
print("")

local rows = {}

local pieces = { "Pawn", "Knight", "Bishop", "Rook", "Queen", "King" }
for _, piece in ipairs(pieces) do
	local s = runBatch(
		string.format("solo-%s x3 T1", piece),
		rosterOf(piece, lives),
		{ transcendenceLevel = 1, upgrades = {} },
		cli,
		config
	)
	table.insert(rows, s)
end

table.insert(
	rows,
	(
		runBatch(
			"roster-P/N/R T1",
			{ "Pawn", "Knight", "Rook" },
			{ transcendenceLevel = 1, upgrades = {} },
			cli,
			config
		)
	)
)

table.insert(
	rows,
	(
		runBatch(
			"roster-full6 T1",
			{ "Pawn", "Knight", "Bishop", "Rook", "Queen", "King" },
			{ transcendenceLevel = 1, upgrades = {} },
			cli,
			config
		)
	)
)

table.insert(
	rows,
	(
		runBatch(
			"solo-Rook x8 T1",
			rosterOf("Rook", 8),
			{ transcendenceLevel = 1, upgrades = {} },
			cli,
			config
		)
	)
)

table.insert(
	rows,
	(
		runBatch(
			"solo-Rook x3 M10V10 T1",
			rosterOf("Rook", 3),
			{ transcendenceLevel = 1, upgrades = { Might = 10, Vitality = 10 } },
			cli,
			config
		)
	)
)

table.insert(
	rows,
	(
		runBatch(
			"solo-Rook x8 M15V15 T1",
			rosterOf("Rook", 8),
			{ transcendenceLevel = 1, upgrades = { Might = 15, Vitality = 15 } },
			cli,
			config
		)
	)
)

for _, t in ipairs({ 1, 2, 3 }) do
	table.insert(
		rows,
		(
			runBatch(
				string.format("solo-Rook x3 T%d", t),
				rosterOf("Rook", 3),
				{ transcendenceLevel = t, upgrades = {} },
				cli,
				config
			)
		)
	)
end

for _, t in ipairs({ 2, 3 }) do
	table.insert(
		rows,
		(
			runBatch(
				string.format("solo-Rook x8 M15V15 T%d", t),
				rosterOf("Rook", 8),
				{ transcendenceLevel = t, upgrades = { Might = 15, Vitality = 15 } },
				cli,
				config
			)
		)
	)
end

print(
	string.format(
		"%-28s %6s %7s %7s %8s %8s %7s %8s",
		"scenario",
		"n",
		"win%",
		"loss%",
		"avgLv",
		"maxLv",
		"avgRnds",
		"1stCmb"
	)
)
print(string.rep("-", 96))

local md = {}
table.insert(md, "# Balance Simulation Report")
table.insert(md, "")
table.insert(
	md,
	string.format(
		"Generated by `scripts/balance_sim.luau` · runs/scenario=%d · lives=%d · maxRounds=%d · seedBase=%d",
		cli.runs,
		lives,
		cli.maxRounds,
		cli.seedBase
	)
)
table.insert(md, "")
table.insert(md, "Policy: greedy SimAI (prefer safe kills / boss priority) + SimEnemy chase.")
table.insert(md, "")
table.insert(
	md,
	"| scenario | n | win% | loss% | timeout% | avg level | max level | avg rounds | avg first combat |"
)
table.insert(md, "|---|---:|---:|---:|---:|---:|---:|---:|---:|")

for _, s in ipairs(rows) do
	local first = if s.avgFirstCombat then num(s.avgFirstCombat, 1) else "—"
	print(
		string.format(
			"%-28s %6d %7s %7s %8s %8d %7s %8s",
			s.label,
			s.n,
			pct(s.winRate),
			pct(s.lossRate),
			num(s.avgLevel, 1),
			s.maxLevel,
			num(s.avgRounds, 0),
			first
		)
	)
	table.insert(
		md,
		string.format(
			"| %s | %d | %.1f%% | %.1f%% | %.1f%% | %.1f | %d | %.0f | %s |",
			s.label,
			s.n,
			s.winRate * 100,
			s.lossRate * 100,
			s.timeoutRate * 100,
			s.avgLevel,
			s.maxLevel,
			s.avgRounds,
			first
		)
	)
end

table.insert(md, "")
table.insert(md, "## Notes")
table.insert(md, "")
table.insert(md, "- **win** = King-boss clear (level ladder reaches King stage and kills boss).")
table.insert(md, "- **loss** = roster exhausted before victory.")
table.insert(md, "- **timeout** = hit maxRounds without terminal state (policy stuck / softlock).")
table.insert(md, "- King stage starts at level **17** with default `ENEMY_COUNT_CAP=12`.")
table.insert(
	md,
	"- This is an AI proxy, not human play — use for relative piece/T/upgrade curves."
)
table.insert(md, "")
table.insert(md, "## Observed signals (auto)")
table.insert(md, "")

-- Auto-detect simple signals
local by = {}
for _, s in ipairs(rows) do
	by[s.label] = s
end

local function note(fmt, ...)
	table.insert(md, "- " .. string.format(fmt, ...))
end

if by["solo-Rook x3 T1"] and by["solo-Rook x3 T3"] then
	note(
		"Rook x3 avg level T1→T3: **%.1f → %.1f** (transcendence wall).",
		by["solo-Rook x3 T1"].avgLevel,
		by["solo-Rook x3 T3"].avgLevel
	)
end
if by["solo-Pawn x3 T1"] and by["solo-Queen x3 T1"] then
	note(
		"Pawn vs Queen avg level (x3 T1): **%.1f vs %.1f**.",
		by["solo-Pawn x3 T1"].avgLevel,
		by["solo-Queen x3 T1"].avgLevel
	)
end
if by["solo-King x3 T1"] and by["solo-Pawn x3 T1"] then
	note(
		"King vs Pawn avg level (x3 T1): **%.1f vs %.1f** (safety premium).",
		by["solo-King x3 T1"].avgLevel,
		by["solo-Pawn x3 T1"].avgLevel
	)
end
if by["solo-Knight x3 T1"] then
	note(
		"Knight timeout rate: **%.0f%%** — L-move cannot capture adjacent enemies that park on you (design softlock risk).",
		by["solo-Knight x3 T1"].timeoutRate * 100
	)
end
if by["solo-Rook x8 M15V15 T1"] then
	note(
		"Rook x8 + M15/V15 win rate: **%.1f%%**, avg level **%.1f**, max **%d** (power budget needed for deep ladder).",
		by["solo-Rook x8 M15V15 T1"].winRate * 100,
		by["solo-Rook x8 M15V15 T1"].avgLevel,
		by["solo-Rook x8 M15V15 T1"].maxLevel
	)
end
note(
	"King boss stage begins at level **17** (`ENEMY_COUNT_CAP=12`). Early wipe at ~Lv3 with 3 lives is expected under current ATK/HP placeholders."
)
note(
	"Tuning levers: `ENEMY_BASE.attack`, piece `attack`/`maxHealth`, `CURRENCY`/`upgrade` curves, lives from shop."
)

local reportPath = "docs/BALANCE_SIM.md"
fs.writeFile(reportPath, table.concat(md, "\n") .. "\n")
print("")
print("Wrote " .. reportPath)
print("Done.")

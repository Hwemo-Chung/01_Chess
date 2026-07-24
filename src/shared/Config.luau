-- Fixed deterministic gameplay configuration. No Roblox dependencies.
-- Balance pass 2026-07-24: early ladder reachable with 3 lives under greedy AI;
-- King boss (~Lv17) still gated by lives/upgrades (see docs/BALANCE_SIM.md).
return {
	BOARD_SIZE = 6,

	BASE_CRIT_CHANCE = 0.15,
	CRIT_DAMAGE_MULTIPLIER = 1.5,

	REROLL_LIMIT = 1,

	ENEMY_COUNT_CAP = 12,
	ENEMY_START_COUNT = 1,
	ENEMY_COUNT_PER_LEVEL = 1,

	-- Tuned down so trades are survivable (was HP10/ATK3 → wipe ~Lv3).
	ENEMY_BASE = { maxHealth = 6, attack = 1 },

	ENEMY_TIER_ORDER = { "Pawn", "Knight", "Bishop", "Rook", "Queen", "King" },

	-- Boss is tanky but not a multi-life sponge at T1.
	BOSS_HEALTH_MULTIPLIER = 2.5,

	STARTING_ROSTER = { "Pawn", "Knight", "Rook" },

	CURRENCY_PER_LEVEL = 8,
	VICTORY_BONUS = 80,

	BISHOP_CRIT_BASE = 0.15,
	BISHOP_CRIT_STEP = 0.05,
	BISHOP_CRIT_CAP = 0.30,

	UPGRADES = {
		Might = {
			displayName = "Might",
			stat = "attackPercent",
			perLevel = 0.06,
			price = 15,
			maxLevel = 25,
		},
		Vitality = {
			displayName = "Vitality",
			stat = "healthPercent",
			perLevel = 0.06,
			price = 15,
			maxLevel = 25,
		},
	},

	DEFAULT_TRANSCENDENCE = 1,
	-- Soft transcendence curve (was raw ×T). T1=1 always.
	-- HP:  T1=1.00  T2=1.50  T3=2.00  T4=2.50
	-- ATK:  T1=1.00  T2=1.35  T3=1.70  T4=2.05  (slower — less one-shot pressure)
	-- Boss HP multiplies base boss cushion × mild T extra (see Transcendence.luau).
	TRANSCENDENCE_HP_PER_LEVEL = 0.50,
	TRANSCENDENCE_ATK_PER_LEVEL = 0.35,
	TRANSCENDENCE_BOSS_PER_LEVEL = 0.12,

	-- Player ATK high enough to one-shot base pawns; HP supports multi-kill chains.
	PIECES = {
		Pawn = {
			maxHealth = 24,
			attack = 6,
			critChance = 0.15,
			price = 10,
			incomingDamageMultiplier = 1,
		},
		Knight = {
			maxHealth = 24,
			attack = 6,
			critChance = 0.30,
			price = 25,
			incomingDamageMultiplier = 1,
		},
		Bishop = {
			maxHealth = 22,
			attack = 6,
			critChance = 0.15,
			price = 30,
			incomingDamageMultiplier = 1,
			critFromDistance = true,
		},
		Rook = {
			maxHealth = 24,
			attack = 7,
			critChance = 0.15,
			price = 40,
			incomingDamageMultiplier = 1,
		},
		Queen = {
			maxHealth = 20,
			attack = 9,
			critChance = 0.15,
			price = 70,
			incomingDamageMultiplier = 1.5,
		},
		King = {
			maxHealth = 32,
			attack = 5,
			critChance = 0.15,
			price = 90,
			incomingDamageMultiplier = 0.5,
		},
	},
}

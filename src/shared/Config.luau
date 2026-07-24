-- Fixed deterministic gameplay configuration. No Roblox dependencies.
return {
	BOARD_SIZE = 6,

	BASE_CRIT_CHANCE = 0.15,
	CRIT_DAMAGE_MULTIPLIER = 1.5,

	REROLL_LIMIT = 1,

	ENEMY_COUNT_CAP = 12,
	ENEMY_START_COUNT = 1,
	ENEMY_COUNT_PER_LEVEL = 1,

	-- Flat fallback when tier table missing a piece (should not happen).
	ENEMY_BASE = { maxHealth = 10, attack = 3 },

	-- After count-cap levels, tier climbs Pawn→…→King (PRD §6.2).
	ENEMY_TIER_ORDER = { "Pawn", "Knight", "Bishop", "Rook", "Queen", "King" },

	-- King boss HP cushion so the life-swap race is meaningful (placeholder).
	BOSS_HEALTH_MULTIPLIER = 3,

	STARTING_ROSTER = { "Pawn", "Knight", "Rook" },

	CURRENCY_PER_LEVEL = 5,
	-- Extra gold on King-clear victory.
	VICTORY_BONUS = 50,

	BISHOP_CRIT_BASE = 0.15,
	BISHOP_CRIT_STEP = 0.05,
	BISHOP_CRIT_CAP = 0.30,

	-- Permanent upgrades (PRD §6.3 / §6.5 transcendence wall answer).
	UPGRADES = {
		Might = {
			displayName = "Might",
			stat = "attackPercent",
			perLevel = 0.05,
			price = 20,
			maxLevel = 25,
		},
		Vitality = {
			displayName = "Vitality",
			stat = "healthPercent",
			perLevel = 0.05,
			price = 20,
			maxLevel = 25,
		},
	},

	-- Transcendence: enemy base HP/ATK × level (PRD §6.5). Min 1.
	DEFAULT_TRANSCENDENCE = 1,

	PIECES = {
		Pawn = {
			maxHealth = 20,
			attack = 5,
			critChance = 0.15,
			price = 10,
			incomingDamageMultiplier = 1,
		},
		Knight = {
			maxHealth = 20,
			attack = 5,
			critChance = 0.30,
			price = 25,
			incomingDamageMultiplier = 1,
		},
		Bishop = {
			maxHealth = 18,
			attack = 5,
			critChance = 0.15,
			price = 30,
			incomingDamageMultiplier = 1,
			critFromDistance = true,
		},
		Rook = {
			maxHealth = 20,
			attack = 5,
			critChance = 0.15,
			price = 40,
			incomingDamageMultiplier = 1,
		},
		Queen = {
			maxHealth = 16,
			attack = 7,
			critChance = 0.15,
			price = 70,
			incomingDamageMultiplier = 1.5,
		},
		King = {
			maxHealth = 28,
			attack = 3,
			critChance = 0.15,
			price = 90,
			incomingDamageMultiplier = 0.5,
		},
	},
}

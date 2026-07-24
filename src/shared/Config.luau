-- Fixed deterministic gameplay configuration. No Roblox dependencies.
return {
	BOARD_SIZE = 6,

	BASE_CRIT_CHANCE = 0.15,
	-- ponytail: crit damage magnitude has no PRD value (open item §12-8).
	CRIT_DAMAGE_MULTIPLIER = 1.5,

	REROLL_LIMIT = 1,

	ENEMY_COUNT_CAP = 12,
	ENEMY_START_COUNT = 1,
	ENEMY_COUNT_PER_LEVEL = 1,

	ENEMY_BASE = { maxHealth = 10, attack = 3 },

	-- Starting lives before any shop purchases (PRD MVP set).
	STARTING_ROSTER = { "Pawn", "Knight", "Rook" },

	-- Run-end currency: level reached × this rate (placeholder; balance deferred).
	CURRENCY_PER_LEVEL = 5,

	-- Bishop distance crit: min(BASE + STEP*(distance-1), CAP) (PRD §6.4.1).
	BISHOP_CRIT_BASE = 0.15,
	BISHOP_CRIT_STEP = 0.05,
	BISHOP_CRIT_CAP = 0.30,

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
			-- base; actual crit uses distance formula when attacking
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
			-- always-on frailty (PRD §6.4.1)
			incomingDamageMultiplier = 1.5,
		},
		King = {
			maxHealth = 28,
			attack = 3,
			critChance = 0.15,
			price = 90,
			-- always-on toughness (PRD §6.4.1)
			incomingDamageMultiplier = 0.5,
		},
	},
}

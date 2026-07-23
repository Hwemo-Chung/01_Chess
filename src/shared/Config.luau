-- Fixed deterministic gameplay configuration. No Roblox dependencies.
return {
	BOARD_SIZE = 6,

	BASE_CRIT_CHANCE = 0.15,
	-- ponytail: crit damage magnitude has no PRD value (open item §12-8).
	-- 1.5x is an MVP placeholder; retune once the deterministic sim (§12-6) runs.
	CRIT_DAMAGE_MULTIPLIER = 1.5,

	REROLL_LIMIT = 1,

	-- ponytail: PRD leaves the enemy count cap "10~14 근방으로 잠정" (§6.2, open
	-- item §12-6). 12 is the MVP working value.
	ENEMY_COUNT_CAP = 12,
	ENEMY_START_COUNT = 1,
	ENEMY_COUNT_PER_LEVEL = 1,

	-- ponytail: MVP has no piece-tier escalation (§11) — every enemy is this one
	-- flat stat block, no crit, no special ability.
	ENEMY_BASE = { maxHealth = 10, attack = 3 },

	-- ponytail: base HP/ATK/price have no PRD numbers either (balance is
	-- explicitly deferred to §12's deterministic sim). Round placeholders below,
	-- one line per piece so they're easy to find and retune.
	PIECES = {
		Pawn = { maxHealth = 20, attack = 5, critChance = 0.15, price = 10 },
		Knight = { maxHealth = 20, attack = 5, critChance = 0.30, price = 25 },
		Rook = { maxHealth = 20, attack = 5, critChance = 0.15, price = 40 },
	},
}

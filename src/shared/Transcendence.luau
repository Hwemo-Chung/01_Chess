-- Pure transcendence scaling (PRD §6.5). Soft linear — not raw ×T —
-- so permanent upgrades can push the wall without exponential blow-up.
local Transcendence = {}

-- T1 → 1.0; each step adds `perLevel` (e.g. 0.5 → T2=1.5, T3=2.0).
function Transcendence.softScale(level: number, perLevel: number): number
	local t = level
	if type(t) ~= "number" or t < 1 then
		t = 1
	end
	t = math.floor(t)
	local step = perLevel
	if type(step) ~= "number" or step < 0 then
		step = 0.5
	end
	return 1 + step * (t - 1)
end

function Transcendence.enemyHpMultiplier(level: number, config: any): number
	return Transcendence.softScale(level, config.TRANSCENDENCE_HP_PER_LEVEL or 0.5)
end

function Transcendence.enemyAtkMultiplier(level: number, config: any): number
	-- ATK grows slower than HP: chip damage wall is harsher than tankiness.
	return Transcendence.softScale(level, config.TRANSCENDENCE_ATK_PER_LEVEL or 0.35)
end

function Transcendence.bossHpMultiplier(level: number, config: any): number
	local base = config.BOSS_HEALTH_MULTIPLIER or 2.5
	-- Mild extra boss HP per T on top of the soft enemy HP scale.
	local extra = Transcendence.softScale(level, config.TRANSCENDENCE_BOSS_PER_LEVEL or 0.15)
	return base * extra
end

-- Display / debug: { hp, atk, bossHp } absolute multipliers vs T1 trash.
function Transcendence.preview(level: number, config: any)
	return {
		level = math.max(1, math.floor(level or 1)),
		hp = Transcendence.enemyHpMultiplier(level, config),
		atk = Transcendence.enemyAtkMultiplier(level, config),
		bossHp = Transcendence.enemyHpMultiplier(level, config)
			* Transcendence.bossHpMultiplier(level, config),
	}
end

return Transcendence

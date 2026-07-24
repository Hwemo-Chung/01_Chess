-- Pure combat resolution: crit rolls, Rook pierce, distance crit, damage preview.
local BoardRules = require("./BoardRules")

local CombatRules = {}

export type AttackerStats = { attack: number, critChance: number }
export type AttackResult = { damage: number, crit: boolean }

function CombatRules.chebyshevDistance(a: BoardRules.Position, b: BoardRules.Position): number
	return math.max(math.abs(a.x - b.x), math.abs(a.z - b.z))
end

-- Bishop: min(base + step*(distance-1), cap). Others: fixed piece critChance.
function CombatRules.critChanceForAttack(
	pieceType: string,
	pieceStats: any,
	origin: BoardRules.Position,
	destination: BoardRules.Position,
	config: any
): number
	if pieceType == "Bishop" or (pieceStats and pieceStats.critFromDistance) then
		local distance = CombatRules.chebyshevDistance(origin, destination)
		local chance = config.BISHOP_CRIT_BASE + config.BISHOP_CRIT_STEP * (distance - 1)
		return math.min(chance, config.BISHOP_CRIT_CAP)
	end
	return pieceStats.critChance
end

function CombatRules.resolveAttack(
	attackerStats: AttackerStats,
	critDamageMultiplier: number,
	rng: any
): AttackResult
	assert(type(attackerStats) == "table", "attackerStats must be a table")
	local roll = rng:next()
	local isCrit = roll < attackerStats.critChance
	local damage = attackerStats.attack
	if isCrit then
		damage *= critDamageMultiplier
	end
	return { damage = damage, crit = isCrit }
end

function CombatRules.resolvePierceTarget(
	pieceType: string,
	origin: BoardRules.Position,
	destination: BoardRules.Position,
	enemyPositions: { BoardRules.Position },
	boardSize: number
): BoardRules.Position?
	if pieceType ~= "Rook" then
		return nil
	end
	local dx = destination.x - origin.x
	local dz = destination.z - origin.z
	if dx ~= 0 then
		dx = dx // math.abs(dx)
	end
	if dz ~= 0 then
		dz = dz // math.abs(dz)
	end
	local behindX, behindZ = destination.x + dx, destination.z + dz
	if behindX < 1 or behindX > boardSize or behindZ < 1 or behindZ > boardSize then
		return nil
	end
	local behind = { x = behindX, z = behindZ }
	if BoardRules.enemyAt(behind, enemyPositions) then
		return behind
	end
	return nil
end

export type MovePreview = {
	kind: string, -- "move" | "attack"
	baseDamage: number,
	critDamage: number,
	critChance: number,
	killChance: number,
	damageTaken: number,
	expectedDamageDealt: number,
	playerDiesIfHit: boolean,
	summary: string,
}

-- Deterministic preview for UI. Does not consume RNG.
function CombatRules.previewDestination(
	pieceType: string,
	pieceStats: any,
	origin: BoardRules.Position,
	destination: BoardRules.Position,
	enemy: any?,
	invulnerable: boolean,
	playerHealth: number,
	config: any
): MovePreview
	if enemy == nil then
		return {
			kind = "move",
			baseDamage = 0,
			critDamage = 0,
			critChance = 0,
			killChance = 0,
			damageTaken = 0,
			expectedDamageDealt = 0,
			playerDiesIfHit = false,
			summary = "Move",
		}
	end

	local critChance =
		CombatRules.critChanceForAttack(pieceType, pieceStats, origin, destination, config)
	local baseDamage = pieceStats.attack
	local critDamage = pieceStats.attack * config.CRIT_DAMAGE_MULTIPLIER
	local mult = pieceStats.incomingDamageMultiplier or 1
	local damageTaken = 0
	if not invulnerable then
		damageTaken = enemy.attack * mult
	end

	local killOnBase = baseDamage >= enemy.health
	local killOnCrit = critDamage >= enemy.health
	local killChance = 0
	if killOnBase then
		killChance = 1
	elseif killOnCrit then
		killChance = critChance
	end

	-- Resolve always applies counterattack when not invulnerable (even on kill).
	local expectedDamage = baseDamage * (1 - critChance) + critDamage * critChance
	local playerDiesIfHit = (not invulnerable) and (playerHealth - damageTaken <= 0)

	local summary = string.format(
		"Hit %d~%d (crit %d%%) · take %d · kill %d%%",
		baseDamage,
		critDamage,
		math.floor(critChance * 100 + 0.5),
		damageTaken,
		math.floor(killChance * 100 + 0.5)
	)

	return {
		kind = "attack",
		baseDamage = baseDamage,
		critDamage = critDamage,
		critChance = critChance,
		killChance = killChance,
		damageTaken = damageTaken,
		expectedDamageDealt = expectedDamage,
		expectedDamageTaken = damageTaken,
		playerDiesIfHit = playerDiesIfHit,
		summary = summary,
	}
end

return CombatRules

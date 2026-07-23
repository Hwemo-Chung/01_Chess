-- Pure combat resolution: crit rolls and Rook's pierce exception to BLOCKED.
local BoardRules = require("./BoardRules")

local CombatRules = {}

export type AttackerStats = { attack: number, critChance: number }
export type AttackResult = { damage: number, crit: boolean }

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

-- Rook's pierce is an explicit, documented EXCEPTION to the BLOCKED rule
-- (PRD §6.1): it only ever applies once the first enemy in the line has
-- actually died (been "pierced through"), never while it's still alive.
-- Call this only after resolveAttack has determined the first enemy died.
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
	-- Normalize to a unit step; destination is always orthogonal from origin
	-- for a Rook attack (BoardRules only ever offers straight-line targets).
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

return CombatRules

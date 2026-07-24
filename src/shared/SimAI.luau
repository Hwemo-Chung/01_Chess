-- Pure greedy player policy for offline balance simulation (no Roblox).
local CombatRules = require("./CombatRules")
local ProfileRules = require("./ProfileRules")

local SimAI = {}

local function chebyshev(a, b): number
	return math.max(math.abs(a.x - b.x), math.abs(a.z - b.z))
end

local function nearestEnemyDistance(pos, enemies): number
	local best = math.huge
	for _, enemy in ipairs(enemies) do
		local d = chebyshev(pos, enemy)
		if d < best then
			best = d
		end
	end
	return best
end

local function findEnemyAt(enemies, position)
	for _, enemy in ipairs(enemies) do
		if enemy.x == position.x and enemy.z == position.z then
			return enemy
		end
	end
	return nil
end

local function knightCanHitFrom(pos, enemy): boolean
	local dx = math.abs(pos.x - enemy.x)
	local dz = math.abs(pos.z - enemy.z)
	return (dx == 1 and dz == 2) or (dx == 2 and dz == 1)
end

local function countKnightAttacks(pos, enemies): number
	local n = 0
	for _, enemy in ipairs(enemies) do
		if knightCanHitFrom(pos, enemy) then
			n += 1
		end
	end
	return n
end

function SimAI.pickMove(state): any?
	local legal = state:legalMovesForActive()
	if #legal == 0 then
		return nil
	end

	local config = state._config
	local pieceStats =
		ProfileRules.effectivePieceStats(config.PIECES[state.activePiece], state._upgrades, config)
	local origin = state.activePosition
	local enemies = state.enemies
	local livesLeft = #state.roster
	local pieceType = state.activePiece

	local attacks = {}
	local walks = {}
	for _, move in ipairs(legal) do
		if findEnemyAt(enemies, move) ~= nil then
			table.insert(attacks, move)
		else
			table.insert(walks, move)
		end
	end

	if #attacks > 0 then
		local best = attacks[1]
		local bestScore = -1e18
		for _, move in ipairs(attacks) do
			local enemy = findEnemyAt(enemies, move)
			local mult = enemy.incomingDamageMultiplier or 1
			local previewEnemy = {
				health = if mult > 0 then enemy.health / mult else enemy.health,
				attack = enemy.attack,
			}
			local preview = CombatRules.previewDestination(
				pieceType,
				pieceStats,
				origin,
				move,
				previewEnemy,
				state.invulnerable,
				state.activeHealth,
				config
			)

			local score = preview.expectedDamageDealt * 10
			score += preview.killChance * 200
			if enemy.isBoss then
				score += 500
			end
			if enemy.health <= pieceStats.attack * mult then
				score += 120
			end

			local selfDies = preview.playerDiesIfHit and preview.killChance < 1
			if selfDies then
				score -= if livesLeft > 0 then 40 else 400
			else
				score -= preview.damageTaken * 2
			end
			score += math.max(0, 40 - enemy.health)

			if score > bestScore then
				bestScore = score
				best = move
			end
		end
		return best
	end

	local best = walks[1] or legal[1]
	local bestScore = -1e18
	for _, move in ipairs(walks) do
		local score = 0
		if pieceType == "Knight" then
			-- Knight cannot attack adjacent; seek L-attack angles, avoid sitting next to enemies.
			score += countKnightAttacks(move, enemies) * 100
			local dist = nearestEnemyDistance(move, enemies)
			if dist <= 1 then
				score -= 80
			else
				score -= dist * 5
			end
		else
			score -= nearestEnemyDistance(move, enemies) * 20
		end
		score += (3.5 - math.abs(move.x - 3.5)) + (3.5 - math.abs(move.z - 3.5))
		if score > bestScore then
			bestScore = score
			best = move
		end
	end
	return best
end

return SimAI

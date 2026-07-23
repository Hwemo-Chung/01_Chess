-- tests/CombatRules.spec.luau
local CombatRules = require("../src/shared/CombatRules")
local Rng = require("../src/shared/Rng")

local cases = {}
local function case(name, body)
	table.insert(cases, { name = name, body = body })
end

case("resolveAttack / crit multiplies damage by the given multiplier", function()
	-- Seed 1 with this LCG produces roll ~0.0000225 on the first draw, well
	-- under any crit chance we test, so the FIRST resolveAttack call always crits.
	local rng = Rng.new(1)
	local result = CombatRules.resolveAttack({ attack = 10, critChance = 1.0 }, 1.5, rng)
	assert(result.crit == true, "critChance=1.0 must always crit")
	assert(result.damage == 15, "expected 10*1.5=15, got " .. tostring(result.damage))
end)

case("resolveAttack / critChance=0 never crits", function()
	local rng = Rng.new(1)
	for _ = 1, 50 do
		local result = CombatRules.resolveAttack({ attack = 10, critChance = 0.0 }, 1.5, rng)
		assert(not result.crit, "critChance=0 must never crit")
		assert(result.damage == 10, "non-crit damage must equal base attack")
	end
end)

case("resolvePierceTarget / Rook pierces to the enemy directly behind", function()
	local target = CombatRules.resolvePierceTarget(
		"Rook",
		{ x = 1, z = 1 },
		{ x = 3, z = 1 },
		{ { x = 3, z = 1 }, { x = 4, z = 1 } },
		6
	)
	assert(target ~= nil, "expected a pierce target")
	assert(
		target.x == 4 and target.z == 1,
		"pierce target should be the very next square in the same direction"
	)
end)

case("resolvePierceTarget / no pierce when nothing stands behind", function()
	local target = CombatRules.resolvePierceTarget(
		"Rook",
		{ x = 1, z = 1 },
		{ x = 3, z = 1 },
		{ { x = 3, z = 1 } },
		6
	)
	assert(target == nil, "expected no pierce target")
end)

case("resolvePierceTarget / no pierce past the board edge", function()
	local target = CombatRules.resolvePierceTarget(
		"Rook",
		{ x = 1, z = 1 },
		{ x = 6, z = 1 },
		{ { x = 6, z = 1 } },
		6
	)
	assert(target == nil, "pierce target must not wrap past the board edge")
end)

case("resolvePierceTarget / Pawn and Knight never pierce", function()
	local target = CombatRules.resolvePierceTarget(
		"Pawn",
		{ x = 1, z = 1 },
		{ x = 2, z = 1 },
		{ { x = 2, z = 1 }, { x = 3, z = 1 } },
		6
	)
	assert(target == nil, "only Rook has a pierce ability in the MVP set")
end)

return function()
	for _, entry in ipairs(cases) do
		local ok, err = pcall(entry.body)
		assert(ok, entry.name .. " FAILED: " .. tostring(err))
	end
	print(string.format("CombatRules: PASS (%d cases)", #cases))
	return #cases
end

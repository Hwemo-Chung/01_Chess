local Transcendence = require("../src/shared/Transcendence")
local Config = require("../src/shared/Config")

local cases = {}
local function case(name, body)
	table.insert(cases, { name = name, body = body })
end

case("softScale / T1 is always 1", function()
	assert(Transcendence.softScale(1, 0.5) == 1, "T1")
	assert(Transcendence.softScale(0, 0.5) == 1, "clamp below 1")
end)

case("softScale / linear steps", function()
	assert(Transcendence.softScale(2, 0.5) == 1.5, "T2")
	assert(Transcendence.softScale(3, 0.5) == 2.0, "T3")
	assert(Transcendence.softScale(4, 0.35) == 1 + 0.35 * 3, "T4 atk curve")
end)

case("config curve / ATK grows slower than HP", function()
	local hp2 = Transcendence.enemyHpMultiplier(2, Config)
	local atk2 = Transcendence.enemyAtkMultiplier(2, Config)
	assert(atk2 < hp2, "ATK soft-scale < HP soft-scale at T2")
	local hp3 = Transcendence.enemyHpMultiplier(3, Config)
	local atk3 = Transcendence.enemyAtkMultiplier(3, Config)
	assert(atk3 < hp3, "ATK soft-scale < HP soft-scale at T3")
	-- Softer than raw ×T
	assert(hp3 < 3, "HP mult at T3 must be < raw ×3")
	assert(atk3 < 3, "ATK mult at T3 must be < raw ×3")
end)

case("preview / exposes boss composite", function()
	local p = Transcendence.preview(3, Config)
	assert(p.level == 3, "level")
	assert(p.bossHp > p.hp, "boss includes cushion")
end)

return function()
	for _, entry in ipairs(cases) do
		local ok, err = pcall(entry.body)
		assert(ok, entry.name .. " FAILED: " .. tostring(err))
	end
	print(string.format("Transcendence: PASS (%d cases)", #cases))
	return #cases
end

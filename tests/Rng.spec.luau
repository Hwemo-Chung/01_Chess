-- tests/Rng.spec.luau
local Rng = require("../src/shared/Rng")

local cases = {}
local function case(name, body)
	table.insert(cases, { name = name, body = body })
end

local function expectEqual(actual, expected, message)
	assert(
		actual == expected,
		string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual))
	)
end

case("Rng / same seed produces same sequence", function()
	local a = Rng.new(42)
	local b = Rng.new(42)
	for i = 1, 5 do
		expectEqual(a:next(), b:next(), "draw " .. i)
	end
end)

case("Rng / different seeds diverge", function()
	local a = Rng.new(1)
	local b = Rng.new(2)
	local same = true
	for _ = 1, 5 do
		if a:next() ~= b:next() then
			same = false
		end
	end
	assert(not same, "different seeds should not produce an identical sequence")
end)

case("Rng / values stay in [0, 1)", function()
	local rng = Rng.new(7)
	for _ = 1, 200 do
		local value = rng:next()
		assert(value >= 0 and value < 1, "value out of range: " .. tostring(value))
	end
end)

case("Rng / rejects non-integer seed", function()
	local ok = pcall(function()
		Rng.new(1.5)
	end)
	assert(not ok, "non-integer seed should assert")
end)

return function()
	for _, entry in ipairs(cases) do
		local ok, err = pcall(entry.body)
		assert(ok, entry.name .. " FAILED: " .. tostring(err))
	end
	print(string.format("Rng: PASS (%d cases)", #cases))
	return #cases
end

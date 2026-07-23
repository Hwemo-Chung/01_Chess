-- Pure seeded PRNG (Lehmer/Park-Miller). Deterministic across Lune and Roblox,
-- and cheap enough to store as part of run state for replay (§10.2 of the PRD).
local Rng = {}
Rng.__index = Rng

local MODULUS = 2147483647
local MULTIPLIER = 48271

export type Rng = typeof(setmetatable({} :: { _state: number }, Rng))

function Rng.new(seed: number): Rng
	assert(type(seed) == "number" and seed % 1 == 0, "seed must be an integer")
	local state = seed % MODULUS
	if state <= 0 then
		state += MODULUS - 1
	end
	return setmetatable({ _state = state }, Rng)
end

function Rng.next(self: Rng): number
	self._state = (self._state * MULTIPLIER) % MODULUS
	return self._state / MODULUS
end

return Rng

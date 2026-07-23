# MVP Core Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the deterministic, server-authoritative core game engine for the 01_Chess MVP — turn-based chess-piece movement, probabilistic combat resolution, roster/lives management, and enemy spawning — as pure Luau modules testable under Lune, plus the Roblox server orchestration layer that wires them to real players. This is the minimum slice that lets the MVP hypothesis (§3.2 of the PRD: "does fighting as one randomly-assigned piece create replay compulsion?") actually be played and measured.

**Architecture:** Mirrors `00_VS`'s proven shape (deterministic pure `shared/` Rules modules with zero Roblox dependencies, wrapped by a stateful server-authoritative controller in `server/`), scaffolded fresh in `01_Chess/` — no code is copied from `00_VS`. Combat, movement legality, and RNG all live in pure modules unit-tested via Lune; `ServerMain.server.luau` and friends wire that pure core to `Players`/`RemoteEvent`s and own all Roblox-specific state.

**Tech Stack:** Rojo 7.7.0, Lune 0.10.5, Selene 0.31.0, StyLua 2.5.2 (rokit-pinned), Luau with `--!strict` type annotations, a hand-rolled `case`/`expectEqual` assertion test framework (matching `00_VS/tests/*.spec.luau`).

## Global Constraints

- Board is a fixed 6×6 grid, never grows (PRD §6.2). Coordinates are 1-indexed `{x, z}` pairs, both in `[1, 6]`.
- Only ONE piece fights at a time; owned pieces are lives (PRD §1/§4).
- MVP piece set is exactly `Pawn`, `Knight`, `Rook` — no Bishop/Queen/King, no piece-tier escalation, no King-clear, no transcendence (PRD §11, all v1).
- Base critical-hit chance is 15% for all pieces (PRD §6.4.1); Knight's ability makes its own crit chance 30%; Rook's ability pierces to a second enemy directly behind the first when the first dies.
- Critical-hit damage magnitude has no PRD value (open item §12-8). This plan uses `1.5` as a named, tunable placeholder — every task that touches it says so.
- Enemy count cap has no PRD value ("10~14 근방으로 잠정", open item §12-6). This plan uses `12` as a named, tunable placeholder.
- Random piece assignment and all combat RNG MUST be server-seeded and part of run state (PRD §10.2) — never `math.random()` global state.
- Sliding pieces (Rook) are BLOCKED by the first piece in their path (PRD §6.1); moving onto an enemy square is always legal and always means attacking it (capture-and-land, PRD §6.1).
- Enemy turn is movement-only; damage only happens on the player's own attack move, and is bidirectional (both sides take damage in that exchange) (PRD §6.1).
- No cash purchases anywhere in this plan's scope — MVP ships with zero monetization (PRD §11).
- Never touch `00_VS/` — this is a brand-new sibling project in `01_Chess/`.

---

## File Structure

```
01_Chess/
├── rokit.toml
├── default.project.json
├── .stylua.toml
├── selene.toml
├── .gitignore
├── package.json
├── src/
│   ├── shared/
│   │   ├── Config.luau        # tunable constants: board size, crit%, piece stats, enemy cap
│   │   ├── Rng.luau            # pure seeded PRNG, part of run state
│   │   ├── BoardRules.luau     # legal-move generation per piece type, BLOCKED sliding logic
│   │   ├── CombatRules.luau    # damage/crit/pierce resolution
│   │   ├── SpawnRules.luau     # enemy count cap, capacity guard, safe-square invariant, safe-respawn target
│   │   └── RunState.luau       # pure run state machine tying the above together
│   └── server/
│       ├── RunController.luau  # stateful wrapper: owns a RunState per player, applies moves
│       ├── EnemyAI.luau        # enemy movement decision (server-side, pure function of state)
│       ├── RemoteGuard.luau    # untrusted-input validation + rate limiting
│       └── ServerMain.server.luau  # entry point: wires RunController to Players/RemoteEvents
├── default.project.json maps ReplicatedStorage/Chess/Shared -> src/shared,
│                             ServerScriptService/Chess -> src/server
└── tests/
    ├── run.luau
    ├── Rng.spec.luau
    ├── BoardRules.spec.luau
    ├── CombatRules.spec.luau
    ├── SpawnRules.spec.luau
    ├── RunState.spec.luau
    └── RemoteGuard.spec.luau
```

Client presentation (board rendering, move-selection input, damage-preview UI, HUD) and the three MVP measurement hooks (restart-after-loss, rounds/session, D1/D7) are a **separate follow-up plan** once this engine is solid — they're tested by manual Studio play, not Lune, which is a different verification loop from everything in this plan.

---

## Task 1: Toolchain Scaffold

**Files:**
- Create: `01_Chess/rokit.toml`
- Create: `01_Chess/default.project.json`
- Create: `01_Chess/.stylua.toml`
- Create: `01_Chess/selene.toml`
- Create: `01_Chess/.gitignore`
- Create: `01_Chess/package.json`
- Create: `01_Chess/src/shared/.gitkeep`, `01_Chess/src/server/.gitkeep` (placeholder so Rojo has non-empty dirs to sync; deleted once real files land in Task 2)

**Interfaces:**
- Produces: a working `rojo build` target and a `lune` binary reachable via rokit, which every later task's tests depend on.

- [ ] **Step 1: Write `rokit.toml`**

```toml
[tools]
rojo = "rojo-rbx/rojo@7.7.0"
lune = "lune-org/lune@0.10.5"
selene = "Kampfkarren/selene@0.31.0"
stylua = "JohnnyMorganz/StyLua@2.5.2"
```

- [ ] **Step 2: Write `default.project.json`**

```json
{
  "name": "Chess",
  "tree": {
    "$className": "DataModel",
    "Workspace": {
      "$className": "Workspace",
      "Floor": {
        "$className": "Part",
        "$properties": {
          "Anchored": true,
          "CanCollide": true,
          "Color": [31, 35, 48],
          "Material": "Slate",
          "Position": [0, 0, 0],
          "Size": [60, 1, 60]
        }
      },
      "SpawnLocation": {
        "$className": "SpawnLocation",
        "$properties": {
          "Anchored": true,
          "CanCollide": true,
          "Duration": 0,
          "Neutral": true,
          "Position": [0, 4, 0],
          "Size": [6, 1, 6]
        }
      }
    },
    "ReplicatedStorage": {
      "$className": "ReplicatedStorage",
      "Chess": {
        "$className": "Folder",
        "Shared": { "$path": "src/shared" }
      }
    },
    "ServerScriptService": {
      "$className": "ServerScriptService",
      "Chess": { "$path": "src/server" }
    }
  }
}
```

- [ ] **Step 3: Write `.stylua.toml`**

```toml
column_width = 100
indent_type = "Tabs"
quote_style = "AutoPreferDouble"
std = "roblox"
```

- [ ] **Step 4: Write `selene.toml`**

```toml
[config]
empty_if = { severity = "warning", except = ["*"] }
```

- [ ] **Step 5: Write `.gitignore`**

```
build/
.tools/bin/
```

- [ ] **Step 6: Write `package.json`**

```json
{
  "name": "chess",
  "private": true,
  "engines": {
    "node": ">=24.13.1 <24.14.0"
  },
  "scripts": {
    "verify:toolchain": "for tool in rojo lune selene stylua; do \"$tool\" --version; done"
  }
}
```

- [ ] **Step 7: Install and verify**

Run:
```bash
cd 01_Chess
rokit install
npm run verify:toolchain
```
Expected: four version lines print (rojo/lune/selene/stylua), no errors.

- [ ] **Step 8: Create placeholder dirs and commit**

```bash
mkdir -p src/shared src/server tests
touch src/shared/.gitkeep src/server/.gitkeep
git add rokit.toml default.project.json .stylua.toml selene.toml .gitignore package.json src/shared/.gitkeep src/server/.gitkeep
git commit -m "chore: scaffold 01_Chess Rojo/rokit toolchain"
```

---

## Task 2: Config and Rng — pure constants and seeded randomness

**Files:**
- Create: `src/shared/Config.luau`
- Create: `src/shared/Rng.luau`
- Test: `tests/Rng.spec.luau`
- Modify: `tests/run.luau` (create if absent, register the `Rng` suite)

**Interfaces:**
- Produces: `Config` (a flat table of constants consumed by every later module), `Rng.new(seed: number) -> Rng`, `Rng:next() -> number` (float in `[0, 1)`, mutates internal state, deterministic for a given seed and call sequence).

- [ ] **Step 1: Write the failing test for Rng**

```lua
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
```

- [ ] **Step 2: Write `tests/run.luau`**

```lua
-- tests/run.luau
local process = require("@lune/process")

local filter = nil
for index, argument in ipairs(process.args) do
	if argument == "--filter" then
		filter = process.args[index + 1]
	end
end

local suites = {
	Rng = function()
		return require("./Rng.spec")
	end,
}

local total = 0
for name, loadSuite in pairs(suites) do
	if filter == nil or string.find(name, filter, 1, true) ~= nil then
		local runSuite = loadSuite()
		total += runSuite()
	end
end

assert(total > 0, "no tests matched filter")
print(string.format("TEST SUMMARY: PASS (%d named cases)", total))
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `cd 01_Chess && lune run tests/run.luau`
Expected: FAIL — `src/shared/Rng` does not exist.

- [ ] **Step 4: Write `src/shared/Rng.luau`**

```lua
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
```

- [ ] **Step 5: Write `src/shared/Config.luau`**

```lua
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
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `lune run tests/run.luau`
Expected: `Rng: PASS (4 cases)` then `TEST SUMMARY: PASS (4 named cases)`.

- [ ] **Step 7: Commit**

```bash
git add src/shared/Config.luau src/shared/Rng.luau tests/Rng.spec.luau tests/run.luau
git rm --cached src/shared/.gitkeep
git commit -m "feat: add Config constants and seeded Rng module"
```

---

## Task 3: BoardRules — legal-move generation and blocking

**Files:**
- Create: `src/shared/BoardRules.luau`
- Test: `tests/BoardRules.spec.luau`
- Modify: `tests/run.luau` (register `BoardRules` suite)

**Interfaces:**
- Consumes: `Config.BOARD_SIZE`
- Produces: `BoardRules.legalMoves(pieceType: string, position: {x: number, z: number}, boardSize: number, enemyPositions: {{x: number, z: number}}) -> {{x: number, z: number}}`, `BoardRules.enemyAt(position, enemyPositions) -> boolean`

- [ ] **Step 1: Write the failing test**

```lua
-- tests/BoardRules.spec.luau
local BoardRules = require("../src/shared/BoardRules")

local cases = {}
local function case(name, body)
	table.insert(cases, { name = name, body = body })
end

local function containsMove(moves, x, z)
	for _, move in ipairs(moves) do
		if move.x == x and move.z == z then
			return true
		end
	end
	return false
end

case("Pawn / 4-directional single step, no diagonals", function()
	local moves = BoardRules.legalMoves("Pawn", { x = 3, z = 3 }, 6, {})
	assert(#moves == 4, "expected exactly 4 moves, got " .. #moves)
	assert(containsMove(moves, 4, 3), "missing +x")
	assert(containsMove(moves, 2, 3), "missing -x")
	assert(containsMove(moves, 3, 4), "missing +z")
	assert(containsMove(moves, 3, 2), "missing -z")
	assert(not containsMove(moves, 4, 4), "diagonal must not be legal")
end)

case("Pawn / corner has exactly 2 legal moves (never zero)", function()
	local moves = BoardRules.legalMoves("Pawn", { x = 1, z = 1 }, 6, {})
	assert(#moves == 2, "expected 2 moves at a corner, got " .. #moves)
end)

case("Knight / center has 8 L-shaped targets", function()
	local moves = BoardRules.legalMoves("Knight", { x = 3, z = 3 }, 6, {})
	assert(#moves == 8, "expected 8 knight moves, got " .. #moves)
	assert(containsMove(moves, 5, 4), "missing L-target (5,4)")
	assert(containsMove(moves, 1, 2), "missing L-target (1,2)")
end)

case("Knight / ignores blocking (no path check needed)", function()
	-- An "enemy" sitting between origin and an L-target should not matter --
	-- knight moves are jumps, never blocked. Legality here means "reachable",
	-- separately from whether it's occupied (occupied = attack target).
	local moves = BoardRules.legalMoves("Knight", { x = 3, z = 3 }, 6, { { x = 4, z = 3 } })
	assert(containsMove(moves, 5, 4), "knight jump must ignore intervening pieces")
end)

case("Rook / slides until board edge on an empty board", function()
	local moves = BoardRules.legalMoves("Rook", { x = 1, z = 1 }, 6, {})
	-- 5 squares along +x, 5 along +z (no -x/-z available from a corner) = 10.
	assert(#moves == 10, "expected 10 moves from a corner on an empty 6x6, got " .. #moves)
end)

case("Rook / BLOCKED — stops at (captures) the first enemy, no further", function()
	local moves = BoardRules.legalMoves("Rook", { x = 1, z = 1 }, 6, { { x = 3, z = 1 } })
	assert(containsMove(moves, 2, 1), "square before the enemy must be reachable")
	assert(containsMove(moves, 3, 1), "the enemy's own square must be a legal capture target")
	assert(not containsMove(moves, 4, 1), "must not see past a blocking enemy")
	assert(not containsMove(moves, 5, 1), "must not see past a blocking enemy")
end)

case("BoardRules.enemyAt / detects occupancy", function()
	local enemies = { { x = 2, z = 2 }, { x = 4, z = 4 } }
	assert(BoardRules.enemyAt({ x = 2, z = 2 }, enemies), "should find enemy at (2,2)")
	assert(not BoardRules.enemyAt({ x = 3, z = 3 }, enemies), "should not find enemy at (3,3)")
end)

case("legalMoves / rejects unknown piece type", function()
	local ok = pcall(function()
		BoardRules.legalMoves("Bishop", { x = 3, z = 3 }, 6, {})
	end)
	assert(not ok, "Bishop is not an MVP piece type and must error")
end)

return function()
	for _, entry in ipairs(cases) do
		local ok, err = pcall(entry.body)
		assert(ok, entry.name .. " FAILED: " .. tostring(err))
	end
	print(string.format("BoardRules: PASS (%d cases)", #cases))
	return #cases
end
```

- [ ] **Step 2: Register the suite in `tests/run.luau`**

```lua
local suites = {
	Rng = function()
		return require("./Rng.spec")
	end,
	BoardRules = function()
		return require("./BoardRules.spec")
	end,
}
```

- [ ] **Step 3: Run to verify failure**

Run: `lune run tests/run.luau --filter BoardRules`
Expected: FAIL — module not found.

- [ ] **Step 4: Write `src/shared/BoardRules.luau`**

```lua
-- Pure legal-move generation. No Roblox dependencies.
local BoardRules = {}

export type Position = { x: number, z: number }

local ORTHOGONAL_DIRECTIONS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
local KNIGHT_OFFSETS = {
	{ 1, 2 },
	{ 2, 1 },
	{ -1, 2 },
	{ -2, 1 },
	{ 1, -2 },
	{ 2, -1 },
	{ -1, -2 },
	{ -2, -1 },
}

local function inBounds(x: number, z: number, boardSize: number): boolean
	return x >= 1 and x <= boardSize and z >= 1 and z <= boardSize
end

local function occupancySet(enemyPositions: { Position }): { [string]: boolean }
	local occupied = {}
	for _, enemy in ipairs(enemyPositions) do
		occupied[enemy.x .. "," .. enemy.z] = true
	end
	return occupied
end

function BoardRules.enemyAt(position: Position, enemyPositions: { Position }): boolean
	for _, enemy in ipairs(enemyPositions) do
		if enemy.x == position.x and enemy.z == position.z then
			return true
		end
	end
	return false
end

function BoardRules.legalMoves(
	pieceType: string,
	position: Position,
	boardSize: number,
	enemyPositions: { Position }
): { Position }
	assert(type(position) == "table" and type(position.x) == "number" and type(position.z) == "number", "position must be {x, z}")
	local moves: { Position } = {}

	if pieceType == "Pawn" then
		for _, direction in ipairs(ORTHOGONAL_DIRECTIONS) do
			local x, z = position.x + direction[1], position.z + direction[2]
			if inBounds(x, z, boardSize) then
				table.insert(moves, { x = x, z = z })
			end
		end
	elseif pieceType == "Knight" then
		for _, offset in ipairs(KNIGHT_OFFSETS) do
			local x, z = position.x + offset[1], position.z + offset[2]
			if inBounds(x, z, boardSize) then
				table.insert(moves, { x = x, z = z })
			end
		end
	elseif pieceType == "Rook" then
		local occupied = occupancySet(enemyPositions)
		for _, direction in ipairs(ORTHOGONAL_DIRECTIONS) do
			local x, z = position.x, position.z
			while true do
				x += direction[1]
				z += direction[2]
				if not inBounds(x, z, boardSize) then
					break
				end
				table.insert(moves, { x = x, z = z })
				if occupied[x .. "," .. z] then
					-- BLOCKED: this square (the enemy) is a legal capture
					-- target, but nothing further along this line is.
					break
				end
			end
		end
	else
		error("unknown MVP piece type: " .. tostring(pieceType))
	end

	return moves
end

return BoardRules
```

- [ ] **Step 5: Run to verify pass**

Run: `lune run tests/run.luau --filter BoardRules`
Expected: `BoardRules: PASS (8 cases)`.

- [ ] **Step 6: Commit**

```bash
git add src/shared/BoardRules.luau tests/BoardRules.spec.luau tests/run.luau
git commit -m "feat: add BoardRules — legal moves, BLOCKED sliding pieces, capture-and-land"
```

---

## Task 4: CombatRules — damage, crit, pierce

**Files:**
- Create: `src/shared/CombatRules.luau`
- Test: `tests/CombatRules.spec.luau`
- Modify: `tests/run.luau` (register `CombatRules` suite)

**Interfaces:**
- Consumes: `Rng` (from Task 2), `Config.CRIT_DAMAGE_MULTIPLIER`
- Produces: `CombatRules.resolveAttack(attackerStats: {attack: number, critChance: number}, critDamageMultiplier: number, rng: Rng) -> {damage: number, crit: boolean}`, `CombatRules.resolvePierceTarget(pieceType: string, origin: BoardRules.Position, destination: BoardRules.Position, enemyPositions: {BoardRules.Position}, boardSize: number) -> BoardRules.Position?` (returns the second enemy's position if a pierce applies, else `nil`)

- [ ] **Step 1: Write the failing test**

```lua
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
	assert(target.x == 4 and target.z == 1, "pierce target should be the very next square in the same direction")
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
```

- [ ] **Step 2: Register the suite in `tests/run.luau`** (add `CombatRules = function() return require("./CombatRules.spec") end` alongside the others)

- [ ] **Step 3: Run to verify failure**

Run: `lune run tests/run.luau --filter CombatRules`
Expected: FAIL — module not found.

- [ ] **Step 4: Write `src/shared/CombatRules.luau`**

```lua
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
```

- [ ] **Step 5: Run to verify pass**

Run: `lune run tests/run.luau --filter CombatRules`
Expected: `CombatRules: PASS (5 cases)`.

- [ ] **Step 6: Commit**

```bash
git add src/shared/CombatRules.luau tests/CombatRules.spec.luau tests/run.luau
git commit -m "feat: add CombatRules — crit resolution and Rook pierce"
```

---

## Task 5: SpawnRules — enemy count cap, capacity guard, safe-square invariant

**Files:**
- Create: `src/shared/SpawnRules.luau`
- Test: `tests/SpawnRules.spec.luau`
- Modify: `tests/run.luau` (register `SpawnRules` suite)

**Interfaces:**
- Consumes: `BoardRules.enemyAt`
- Produces: `SpawnRules.enemyCountForLevel(level: number, cap: number, startCount: number, perLevel: number) -> number`, `SpawnRules.hasSafeSquare(boardSize: number, enemyPositions: {BoardRules.Position}, excludePosition: BoardRules.Position?) -> boolean`, `SpawnRules.farthestSafeSquare(boardSize: number, enemyPositions: {BoardRules.Position}) -> BoardRules.Position?`, `SpawnRules.fitsOnBoard(enemyCount: number, boardSize: number) -> boolean`

- [ ] **Step 1: Write the failing test**

```lua
-- tests/SpawnRules.spec.luau
local SpawnRules = require("../src/shared/SpawnRules")

local cases = {}
local function case(name, body)
	table.insert(cases, { name = name, body = body })
end

case("enemyCountForLevel / ramps up then plateaus at the cap", function()
	assert(SpawnRules.enemyCountForLevel(1, 12, 1, 1) == 1, "level 1")
	assert(SpawnRules.enemyCountForLevel(2, 12, 1, 1) == 2, "level 2")
	assert(SpawnRules.enemyCountForLevel(20, 12, 1, 1) == 12, "level 20 must plateau at the cap, not keep climbing")
end)

case("fitsOnBoard / rejects a level whose enemy count exceeds usable tiles", function()
	-- 6x6 = 36 tiles, 1 reserved for the player = 35 usable.
	assert(SpawnRules.fitsOnBoard(35, 6), "35 enemies must fit on a 6x6 board")
	assert(not SpawnRules.fitsOnBoard(36, 6), "36 enemies must NOT fit (no room for the player)")
end)

case("hasSafeSquare / true on an empty board", function()
	assert(SpawnRules.hasSafeSquare(6, {}, nil), "an empty board always has a safe square")
end)

case("hasSafeSquare / false when every square is occupied or adjacent to an enemy", function()
	-- Pack a 3x3 board (9 tiles) with kings-graph-dominating occupants so that
	-- every square is either occupied or 8-adjacent to one -- corners of a
	-- 3x3 at (1,1) and (3,3) do NOT dominate the center-edge tiles, so use a
	-- denser, unambiguous case: occupy every single tile on a 2x2 board.
	local enemies = { { x = 1, z = 1 }, { x = 1, z = 2 }, { x = 2, z = 1 }, { x = 2, z = 2 } }
	assert(not SpawnRules.hasSafeSquare(2, enemies, nil), "fully occupied 2x2 board has no safe square")
end)

case("farthestSafeSquare / picks the square with zero adjacent enemies farthest from them", function()
	local enemies = { { x = 1, z = 1 } }
	local target = SpawnRules.farthestSafeSquare(6, enemies)
	assert(target ~= nil, "expected a safe square")
	-- The farthest corner from (1,1) on a 6x6 board is (6,6).
	assert(target.x == 6 and target.z == 6, "expected the opposite corner, got (" .. target.x .. "," .. target.z .. ")")
end)

case("farthestSafeSquare / nil when the board has no safe square at all", function()
	local enemies = { { x = 1, z = 1 }, { x = 1, z = 2 }, { x = 2, z = 1 }, { x = 2, z = 2 } }
	local target = SpawnRules.farthestSafeSquare(2, enemies)
	assert(target == nil, "expected nil when no safe square exists")
end)

return function()
	for _, entry in ipairs(cases) do
		local ok, err = pcall(entry.body)
		assert(ok, entry.name .. " FAILED: " .. tostring(err))
	end
	print(string.format("SpawnRules: PASS (%d cases)", #cases))
	return #cases
end
```

- [ ] **Step 2: Register the suite in `tests/run.luau`**

- [ ] **Step 3: Run to verify failure**

Run: `lune run tests/run.luau --filter SpawnRules`
Expected: FAIL — module not found.

- [ ] **Step 4: Write `src/shared/SpawnRules.luau`**

```lua
-- Pure spawn-capacity and safe-square invariants. No Roblox dependencies.
local BoardRules = require("./BoardRules")

local SpawnRules = {}

function SpawnRules.enemyCountForLevel(level: number, cap: number, startCount: number, perLevel: number): number
	assert(level >= 1, "level must be at least 1")
	local count = startCount + (level - 1) * perLevel
	return math.min(count, cap)
end

-- 36 tiles total, minus 1 for the player, is the hard ceiling this asserts.
-- Proven necessary in the PRD (§6.2) via the pigeonhole principle: an
-- uncapped count against a fixed board always eventually exceeds it.
function SpawnRules.fitsOnBoard(enemyCount: number, boardSize: number): boolean
	return enemyCount <= (boardSize * boardSize) - 1
end

local function isAdjacentOrEqual(a: BoardRules.Position, b: BoardRules.Position): boolean
	return math.abs(a.x - b.x) <= 1 and math.abs(a.z - b.z) <= 1
end

-- A "safe" square is one that is neither occupied by an enemy nor adjacent
-- to one -- the invariant safe-respawn (farthest teleport) and zugzwang
-- mitigation (guaranteed non-adjacent legal move) both depend on at least
-- one such square existing (PRD §6.1/§6.2).
function SpawnRules.hasSafeSquare(
	boardSize: number,
	enemyPositions: { BoardRules.Position },
	excludePosition: BoardRules.Position?
): boolean
	for x = 1, boardSize do
		for z = 1, boardSize do
			local candidate = { x = x, z = z }
			if excludePosition == nil or not (candidate.x == excludePosition.x and candidate.z == excludePosition.z) then
				local safe = true
				for _, enemy in ipairs(enemyPositions) do
					if isAdjacentOrEqual(candidate, enemy) then
						safe = false
						break
					end
				end
				if safe then
					return true
				end
			end
		end
	end
	return false
end

function SpawnRules.farthestSafeSquare(
	boardSize: number,
	enemyPositions: { BoardRules.Position }
): BoardRules.Position?
	local best: BoardRules.Position? = nil
	local bestDistance = -1
	for x = 1, boardSize do
		for z = 1, boardSize do
			local candidate = { x = x, z = z }
			local safe = true
			local nearestEnemyDistance = math.huge
			for _, enemy in ipairs(enemyPositions) do
				if isAdjacentOrEqual(candidate, enemy) then
					safe = false
					break
				end
				local distance = math.max(math.abs(candidate.x - enemy.x), math.abs(candidate.z - enemy.z))
				if distance < nearestEnemyDistance then
					nearestEnemyDistance = distance
				end
			end
			if safe and nearestEnemyDistance > bestDistance then
				bestDistance = nearestEnemyDistance
				best = candidate
			end
		end
	end
	return best
end

return SpawnRules
```

- [ ] **Step 5: Run to verify pass**

Run: `lune run tests/run.luau --filter SpawnRules`
Expected: `SpawnRules: PASS (6 cases)`.

- [ ] **Step 6: Commit**

```bash
git add src/shared/SpawnRules.luau tests/SpawnRules.spec.luau tests/run.luau
git commit -m "feat: add SpawnRules — count cap, capacity guard, safe-square invariant"
```

---

## Task 6: RunState — the pure run state machine

This is the task where every prior module gets tied together into the actual turn loop.

**Files:**
- Create: `src/shared/RunState.luau`
- Test: `tests/RunState.spec.luau`
- Modify: `tests/run.luau` (register `RunState` suite)

**Interfaces:**
- Consumes: `Rng.new`, `Rng:next`, `BoardRules.legalMoves`, `BoardRules.enemyAt`, `CombatRules.resolveAttack`, `CombatRules.resolvePierceTarget`, `SpawnRules.enemyCountForLevel`, `SpawnRules.fitsOnBoard`, `SpawnRules.farthestSafeSquare`, `Config`
- Produces: `RunState.new(roster: {string}, seed: number, config: table) -> RunState`, and instance methods `:assignRandomPiece()`, `:reroll() -> boolean`, `:legalMovesForActive() -> {BoardRules.Position}`, `:applyPlayerMove(destination) -> {playerDamageDealt: number, playerDamageTaken: number, crit: boolean, pierced: boolean, enemyDied: boolean, levelCleared: boolean, runOver: boolean}`, `:snapshot() -> table` (read-only view for the server layer / tests)

- [ ] **Step 1: Write the failing test**

```lua
-- tests/RunState.spec.luau
local RunState = require("../src/shared/RunState")
local Config = require("../src/shared/Config")

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

case("RunState.new / starts unassigned with the full roster", function()
	local state = RunState.new({ "Pawn", "Knight", "Rook" }, 1, Config)
	local snapshot = state:snapshot()
	expectEqual(snapshot.activePiece, nil, "no piece assigned yet")
	expectEqual(#snapshot.roster, 3, "roster should start with all 3 pieces")
end)

case("assignRandomPiece / draws from the roster and removes it", function()
	local state = RunState.new({ "Pawn", "Knight", "Rook" }, 5, Config)
	state:assignRandomPiece()
	local snapshot = state:snapshot()
	assert(snapshot.activePiece ~= nil, "a piece should now be active")
	expectEqual(#snapshot.roster, 2, "roster should shrink by one")
	expectEqual(snapshot.activeHealth, Config.PIECES[snapshot.activePiece].maxHealth, "active piece starts at full health")
	expectEqual(snapshot.invulnerable, true, "freshly assigned piece is invulnerable for its first turn")
end)

case("reroll / returns the rejected piece to the pool and draws again", function()
	local state = RunState.new({ "Pawn", "Knight", "Rook" }, 1, Config)
	state:assignRandomPiece()
	local firstDraw = state:snapshot().activePiece
	local ok = state:reroll()
	assert(ok, "first reroll must be accepted")
	local snapshot = state:snapshot()
	expectEqual(#snapshot.roster, 2, "roster size must be unchanged after a reroll (return one, draw one)")
	-- Without-replacement: the rejected piece must not be the new draw.
	assert(snapshot.activePiece ~= firstDraw, "reroll must not redraw the exact piece just rejected")
end)

case("reroll / rejected once per assignment (REROLL_LIMIT = 1)", function()
	local state = RunState.new({ "Pawn", "Knight", "Rook" }, 1, Config)
	state:assignRandomPiece()
	assert(state:reroll(), "first reroll must succeed")
	assert(not state:reroll(), "second reroll on the same assignment must be rejected")
end)

case("applyPlayerMove / rejects an illegal destination", function()
	local state = RunState.new({ "Pawn" }, 1, Config)
	state:assignRandomPiece()
	local ok = pcall(function()
		state:applyPlayerMove({ x = 6, z = 6 })
	end)
	assert(not ok, "a destination outside legal moves must error")
end)

case("applyPlayerMove / moving into an empty square just moves, no combat", function()
	local state = RunState.new({ "Pawn" }, 1, Config)
	state:assignRandomPiece()
	local before = state:snapshot()
	local destination = state:legalMovesForActive()[1]
	local result = state:applyPlayerMove(destination)
	expectEqual(result.playerDamageDealt, 0, "no enemy present, no damage dealt")
	expectEqual(result.playerDamageTaken, 0, "no enemy present, no damage taken")
	local after = state:snapshot()
	expectEqual(after.activePosition.x, destination.x, "piece moved to the destination")
	expectEqual(after.activePosition.z, destination.z, "piece moved to the destination")
end)

case("applyPlayerMove / attacking a surviving enemy deals bidirectional damage and does not move", function()
	local state = RunState.new({ "Pawn" }, 1, Config)
	state:assignRandomPiece()
	local origin = state:snapshot().activePosition
	-- Place a very tanky enemy directly adjacent so it's guaranteed to survive one hit.
	state:_debugSetEnemies({ { x = origin.x + 1, z = origin.z, health = 9999, maxHealth = 9999, attack = 2 } })
	local result = state:applyPlayerMove({ x = origin.x + 1, z = origin.z })
	assert(result.playerDamageDealt > 0, "should have dealt damage")
	assert(result.playerDamageTaken == 2, "enemy attack is 2")
	assert(not result.enemyDied, "the tanky enemy should survive")
	local after = state:snapshot()
	expectEqual(after.activePosition.x, origin.x, "attacker stays put when the target survives")
	expectEqual(after.activePosition.z, origin.z, "attacker stays put when the target survives")
end)

case("applyPlayerMove / killing an enemy captures the square (lands on it)", function()
	local state = RunState.new({ "Pawn" }, 1, Config)
	state:assignRandomPiece()
	local origin = state:snapshot().activePosition
	state:_debugSetEnemies({ { x = origin.x + 1, z = origin.z, health = 1, maxHealth = 1, attack = 0 } })
	local result = state:applyPlayerMove({ x = origin.x + 1, z = origin.z })
	assert(result.enemyDied, "a 1-HP enemy must die to any positive damage")
	local after = state:snapshot()
	expectEqual(after.activePosition.x, origin.x + 1, "capturing piece lands on the now-empty square")
	expectEqual(#after.enemies, 0, "dead enemy must be removed from state")
end)

case("applyPlayerMove / Rook pierce damages a second enemy behind the first", function()
	local state = RunState.new({ "Rook" }, 1, Config)
	state:assignRandomPiece()
	local origin = state:snapshot().activePosition
	state:_debugSetEnemies({
		{ x = origin.x + 1, z = origin.z, health = 1, maxHealth = 1, attack = 0 },
		{ x = origin.x + 2, z = origin.z, health = 5, maxHealth = 5, attack = 0 },
	})
	local result = state:applyPlayerMove({ x = origin.x + 1, z = origin.z })
	assert(result.pierced, "expected the pierce flag to be set")
	local after = state:snapshot()
	local pierced = after.enemies[1]
	expectEqual(pierced.x, origin.x + 2, "pierced enemy is the one behind the first")
	assert(pierced.health < 5, "pierced enemy must have taken damage")
end)

case("applyPlayerMove / roster exhausted ends the run", function()
	local state = RunState.new({ "Pawn" }, 1, Config)
	state:assignRandomPiece()
	-- Force the active piece's health to 1 and have it walk into a lethal enemy.
	state:_debugSetActiveHealth(1)
	local origin = state:snapshot().activePosition
	state:_debugSetEnemies({ { x = origin.x + 1, z = origin.z, health = 9999, maxHealth = 9999, attack = 50 } })
	local result = state:applyPlayerMove({ x = origin.x + 1, z = origin.z })
	assert(result.runOver, "roster had only 1 piece; its death must end the run")
end)

case("applyPlayerMove / death with pieces remaining redraws via safe respawn", function()
	local state = RunState.new({ "Pawn", "Knight" }, 3, Config)
	state:assignRandomPiece()
	state:_debugSetActiveHealth(1)
	local origin = state:snapshot().activePosition
	state:_debugSetEnemies({ { x = origin.x + 1, z = origin.z, health = 9999, maxHealth = 9999, attack = 50 } })
	local result = state:applyPlayerMove({ x = origin.x + 1, z = origin.z })
	assert(not result.runOver, "one piece remains, the run must continue")
	local after = state:snapshot()
	assert(after.activePiece ~= nil, "a new piece must be assigned")
	expectEqual(after.invulnerable, true, "the redrawn piece is invulnerable for its first turn")
end)

return function()
	for _, entry in ipairs(cases) do
		local ok, err = pcall(entry.body)
		assert(ok, entry.name .. " FAILED: " .. tostring(err))
	end
	print(string.format("RunState: PASS (%d cases)", #cases))
	return #cases
end
```

- [ ] **Step 2: Register the suite in `tests/run.luau`**

- [ ] **Step 3: Run to verify failure**

Run: `lune run tests/run.luau --filter RunState`
Expected: FAIL — module not found.

- [ ] **Step 4: Write `src/shared/RunState.luau`**

```lua
-- Pure run-state machine tying BoardRules/CombatRules/SpawnRules/Rng together.
-- No Roblox dependencies -- server/RunController.luau is the only thing that
-- touches Players/DataStore/RemoteEvents.
local BoardRules = require("./BoardRules")
local CombatRules = require("./CombatRules")
local SpawnRules = require("./SpawnRules")
local Rng = require("./Rng")

local RunState = {}
RunState.__index = RunState

local START_POSITION = { x = 3, z = 3 }

local function copyArray(source)
	local result = {}
	for index, value in ipairs(source) do
		result[index] = value
	end
	return result
end

function RunState.new(roster: { string }, seed: number, config: any)
	assert(type(roster) == "table" and #roster > 0, "roster must be a non-empty array")
	return setmetatable({
		_config = config,
		_rng = Rng.new(seed),
		roster = copyArray(roster),
		activePiece = nil :: string?,
		activeHealth = 0,
		activeMaxHealth = 0,
		activePosition = { x = START_POSITION.x, z = START_POSITION.z },
		rerollsUsed = 0,
		invulnerable = false,
		level = 1,
		enemies = {},
	}, RunState)
end

local function drawFromRoster(self, excludePiece: string?)
	local candidates = {}
	for _, piece in ipairs(self.roster) do
		if piece ~= excludePiece then
			table.insert(candidates, piece)
		end
	end
	-- If excluding would empty the pool (e.g. a single-piece roster), fall
	-- back to drawing from the full roster instead of erroring.
	local pool = #candidates > 0 and candidates or self.roster
	local index = math.floor(self._rng:next() * #pool) + 1
	index = math.min(index, #pool)
	local drawn = pool[index]
	for position, piece in ipairs(self.roster) do
		if piece == drawn then
			table.remove(self.roster, position)
			break
		end
	end
	return drawn
end

local function spawnEnemiesForLevel(self)
	local config = self._config
	local count = SpawnRules.enemyCountForLevel(
		self.level,
		config.ENEMY_COUNT_CAP,
		config.ENEMY_START_COUNT,
		config.ENEMY_COUNT_PER_LEVEL
	)
	assert(SpawnRules.fitsOnBoard(count, config.BOARD_SIZE), "enemy count must fit on the board")
	local enemies = {}
	local occupied = { [self.activePosition.x .. "," .. self.activePosition.z] = true }
	while #enemies < count do
		local x = math.floor(self._rng:next() * config.BOARD_SIZE) + 1
		local z = math.floor(self._rng:next() * config.BOARD_SIZE) + 1
		local key = x .. "," .. z
		if not occupied[key] then
			occupied[key] = true
			table.insert(enemies, {
				x = x,
				z = z,
				health = config.ENEMY_BASE.maxHealth,
				maxHealth = config.ENEMY_BASE.maxHealth,
				attack = config.ENEMY_BASE.attack,
			})
		end
	end
	self.enemies = enemies
end

function RunState.assignRandomPiece(self)
	local piece = drawFromRoster(self, nil)
	local stats = self._config.PIECES[piece]
	self.activePiece = piece
	self.activeHealth = stats.maxHealth
	self.activeMaxHealth = stats.maxHealth
	self.rerollsUsed = 0
	self.invulnerable = true
	if self.activePosition == nil then
		self.activePosition = { x = START_POSITION.x, z = START_POSITION.z }
	end
	if #self.enemies == 0 then
		spawnEnemiesForLevel(self)
	end
end

function RunState.reroll(self): boolean
	if self.rerollsUsed >= self._config.REROLL_LIMIT then
		return false
	end
	self.rerollsUsed += 1
	local rejected = self.activePiece
	table.insert(self.roster, rejected)
	local piece = drawFromRoster(self, rejected)
	local stats = self._config.PIECES[piece]
	self.activePiece = piece
	self.activeHealth = stats.maxHealth
	self.activeMaxHealth = stats.maxHealth
	self.invulnerable = true
	return true
end

function RunState.legalMovesForActive(self)
	assert(self.activePiece ~= nil, "no active piece assigned")
	return BoardRules.legalMoves(self.activePiece, self.activePosition, self._config.BOARD_SIZE, self.enemies)
end

local function removeEnemyAt(enemies, position)
	for index, enemy in ipairs(enemies) do
		if enemy.x == position.x and enemy.z == position.z then
			table.remove(enemies, index)
			return
		end
	end
end

local function findEnemyAt(enemies, position)
	for _, enemy in ipairs(enemies) do
		if enemy.x == position.x and enemy.z == position.z then
			return enemy
		end
	end
	return nil
end

function RunState.applyPlayerMove(self, destination: BoardRules.Position)
	assert(self.activePiece ~= nil, "no active piece assigned")
	local legal = self:legalMovesForActive()
	local isLegal = false
	for _, move in ipairs(legal) do
		if move.x == destination.x and move.z == destination.z then
			isLegal = true
			break
		end
	end
	assert(isLegal, "destination is not a legal move for the active piece")

	local pieceStats = self._config.PIECES[self.activePiece]
	local result = {
		playerDamageDealt = 0,
		playerDamageTaken = 0,
		crit = false,
		pierced = false,
		enemyDied = false,
		levelCleared = false,
		runOver = false,
	}

	local target = findEnemyAt(self.enemies, destination)
	if target == nil then
		self.activePosition = { x = destination.x, z = destination.z }
		self.invulnerable = false
		return result
	end

	local attack = CombatRules.resolveAttack(
		{ attack = pieceStats.attack, critChance = pieceStats.critChance },
		self._config.CRIT_DAMAGE_MULTIPLIER,
		self._rng
	)
	result.crit = attack.crit
	result.playerDamageDealt = attack.damage
	target.health -= attack.damage
	result.enemyDied = target.health <= 0

	if not self.invulnerable then
		result.playerDamageTaken = target.attack
		self.activeHealth -= target.attack
	end
	self.invulnerable = false

	if result.enemyDied then
		removeEnemyAt(self.enemies, destination)
		self.activePosition = { x = destination.x, z = destination.z }

		local pierceTarget = CombatRules.resolvePierceTarget(
			self.activePiece,
			self.activePosition,
			destination,
			self.enemies,
			self._config.BOARD_SIZE
		)
		if pierceTarget ~= nil then
			local pierced = findEnemyAt(self.enemies, pierceTarget)
			if pierced ~= nil then
				pierced.health -= attack.damage
				result.pierced = true
				if pierced.health <= 0 then
					removeEnemyAt(self.enemies, pierceTarget)
				end
			end
		end
	end

	if self.activeHealth <= 0 then
		if #self.roster == 0 then
			result.runOver = true
		else
			self:assignRandomPiece()
			local safeSquare = SpawnRules.farthestSafeSquare(self._config.BOARD_SIZE, self.enemies)
			if safeSquare ~= nil then
				self.activePosition = safeSquare
			end
		end
	elseif #self.enemies == 0 then
		result.levelCleared = true
		self.level += 1
		spawnEnemiesForLevel(self)
	end

	return result
end

function RunState.snapshot(self)
	return {
		roster = copyArray(self.roster),
		activePiece = self.activePiece,
		activeHealth = self.activeHealth,
		activeMaxHealth = self.activeMaxHealth,
		activePosition = { x = self.activePosition.x, z = self.activePosition.z },
		invulnerable = self.invulnerable,
		level = self.level,
		enemies = copyArray(self.enemies),
	}
end

-- Test-only seams. Never called outside tests/server RunController in ways
-- that bypass legality -- these exist purely so combat-resolution tests
-- don't have to depend on RNG-driven spawn placement to set up scenarios.
function RunState._debugSetEnemies(self, enemies)
	self.enemies = enemies
end

function RunState._debugSetActiveHealth(self, health)
	self.activeHealth = health
end

return RunState
```

- [ ] **Step 5: Run to verify pass**

Run: `lune run tests/run.luau --filter RunState`
Expected: `RunState: PASS (11 cases)`.

- [ ] **Step 6: Commit**

```bash
git add src/shared/RunState.luau tests/RunState.spec.luau tests/run.luau
git commit -m "feat: add RunState — the pure turn/combat/lifecycle state machine"
```

---

## Task 7: RemoteGuard — untrusted input validation

**Files:**
- Create: `src/server/RemoteGuard.luau`
- Test: `tests/RemoteGuard.spec.luau`
- Modify: `tests/run.luau` (register `RemoteGuard` suite)

**Interfaces:**
- Produces: `RemoteGuard.new(clock: () -> number) -> Guard`, `Guard:validateMove(playerUserId, wire: {argc: number, args: {unknown}}, snapshot: {phase: string}) -> {accepted: boolean, reason: string}`, `Guard:validateReroll(playerUserId, wire, snapshot) -> {accepted: boolean, reason: string}`

- [ ] **Step 1: Write the failing test**

```lua
-- tests/RemoteGuard.spec.luau
local RemoteGuard = require("../src/server/RemoteGuard")

local cases = {}
local function case(name, body)
	table.insert(cases, { name = name, body = body })
end

local function fixedClock()
	local now = 0
	return function()
		return now
	end, function(delta)
		now += delta
	end
end

case("validateMove / accepts two numeric args during Turn phase", function()
	local clock = fixedClock()
	local guard = RemoteGuard.new(clock)
	local result = guard:validateMove(1, { argc = 2, args = { 3, 4 } }, { phase = "Turn" })
	assert(result.accepted, "expected acceptance, got reason=" .. result.reason)
end)

case("validateMove / rejects wrong argument count", function()
	local clock = fixedClock()
	local guard = RemoteGuard.new(clock)
	local result = guard:validateMove(1, { argc = 1, args = { 3 } }, { phase = "Turn" })
	assert(not result.accepted and result.reason == "bad_arguments", "expected bad_arguments")
end)

case("validateMove / rejects non-numeric coordinates", function()
	local clock = fixedClock()
	local guard = RemoteGuard.new(clock)
	local result = guard:validateMove(1, { argc = 2, args = { "x", 4 } }, { phase = "Turn" })
	assert(not result.accepted and result.reason == "bad_arguments", "expected bad_arguments")
end)

case("validateMove / rejects wrong phase", function()
	local clock = fixedClock()
	local guard = RemoteGuard.new(clock)
	local result = guard:validateMove(1, { argc = 2, args = { 3, 4 } }, { phase = "AwaitingAssignment" })
	assert(not result.accepted and result.reason == "wrong_phase", "expected wrong_phase")
end)

case("validateMove / rate limited past 4 accepted requests per second", function()
	local clock, advance = fixedClock()
	local guard = RemoteGuard.new(clock)
	for i = 1, 4 do
		local result = guard:validateMove(1, { argc = 2, args = { 3, 4 } }, { phase = "Turn" })
		assert(result.accepted, "request " .. i .. " should be accepted")
	end
	local fifth = guard:validateMove(1, { argc = 2, args = { 3, 4 } }, { phase = "Turn" })
	assert(not fifth.accepted and fifth.reason == "rate_limited", "5th request within the window must be rate limited")
	advance(1.1)
	local sixth = guard:validateMove(1, { argc = 2, args = { 3, 4 } }, { phase = "Turn" })
	assert(sixth.accepted, "request after the window elapses must be accepted")
end)

case("validateReroll / accepts zero-argument requests during Turn phase, rate limited to 1/sec", function()
	local clock, advance = fixedClock()
	local guard = RemoteGuard.new(clock)
	local first = guard:validateReroll(1, { argc = 0, args = {} }, { phase = "Turn" })
	assert(first.accepted, "first reroll request should be accepted")
	local second = guard:validateReroll(1, { argc = 0, args = {} }, { phase = "Turn" })
	assert(not second.accepted and second.reason == "rate_limited", "second reroll within the window must be rate limited")
	advance(1.1)
	local third = guard:validateReroll(1, { argc = 0, args = {} }, { phase = "Turn" })
	assert(third.accepted, "reroll after the window elapses must be accepted")
end)

return function()
	for _, entry in ipairs(cases) do
		local ok, err = pcall(entry.body)
		assert(ok, entry.name .. " FAILED: " .. tostring(err))
	end
	print(string.format("RemoteGuard: PASS (%d cases)", #cases))
	return #cases
end
```

- [ ] **Step 2: Register the suite in `tests/run.luau`**

- [ ] **Step 3: Run to verify failure**

Run: `lune run tests/run.luau --filter RemoteGuard`
Expected: FAIL — module not found.

- [ ] **Step 4: Write `src/server/RemoteGuard.luau`**

```lua
-- Pure validation and per-player accepted-request windows for untrusted
-- remote ingress. Mirrors 00_VS's RemoteGuard shape (sliding-window rate
-- limits, deterministic rejection precedence) for a different wire schema.
local RemoteGuard = {}
RemoteGuard.__index = RemoteGuard

local MOVE_LIMIT = 4
local REROLL_LIMIT = 1
local WINDOW_SECONDS = 1

local function result(accepted: boolean, reason: string)
	return { accepted = accepted, reason = reason }
end

local function exactArgs(wire, expected: number): boolean
	if type(wire) ~= "table" or wire.argc ~= expected or type(wire.args) ~= "table" then
		return false
	end
	for index = 1, expected do
		if wire.args[index] == nil then
			return false
		end
	end
	return true
end

local function acceptedAt(clock, windows, userId, limit, windowSeconds): boolean
	local now = clock()
	local previous = windows[userId] or {}
	local retained = {}
	for _, timestamp in ipairs(previous) do
		if timestamp > now - windowSeconds then
			table.insert(retained, timestamp)
		end
	end
	if #retained >= limit then
		windows[userId] = retained
		return false
	end
	table.insert(retained, now)
	windows[userId] = retained
	return true
end

function RemoteGuard.new(clock: () -> number)
	assert(type(clock) == "function", "clock must be a function")
	return setmetatable({
		_clock = clock,
		_moveWindows = {},
		_rerollWindows = {},
	}, RemoteGuard)
end

function RemoteGuard.validateMove(self, playerUserId: number, wire, snapshot)
	if not exactArgs(wire, 2) or type(wire.args[1]) ~= "number" or type(wire.args[2]) ~= "number" then
		return result(false, "bad_arguments")
	end
	if type(snapshot) ~= "table" or snapshot.phase ~= "Turn" then
		return result(false, "wrong_phase")
	end
	if not acceptedAt(self._clock, self._moveWindows, playerUserId, MOVE_LIMIT, WINDOW_SECONDS) then
		return result(false, "rate_limited")
	end
	return result(true, "ok")
end

function RemoteGuard.validateReroll(self, playerUserId: number, wire, snapshot)
	if not exactArgs(wire, 0) then
		return result(false, "bad_arguments")
	end
	if type(snapshot) ~= "table" or snapshot.phase ~= "Turn" then
		return result(false, "wrong_phase")
	end
	if not acceptedAt(self._clock, self._rerollWindows, playerUserId, REROLL_LIMIT, WINDOW_SECONDS) then
		return result(false, "rate_limited")
	end
	return result(true, "ok")
end

return RemoteGuard
```

- [ ] **Step 5: Run to verify pass**

Run: `lune run tests/run.luau --filter RemoteGuard`
Expected: `RemoteGuard: PASS (6 cases)`.

- [ ] **Step 6: Commit**

```bash
git add src/server/RemoteGuard.luau tests/RemoteGuard.spec.luau tests/run.luau
git commit -m "feat: add RemoteGuard — rate-limited validation for move/reroll remotes"
```

---

## Task 8: RunController — server-authoritative wrapper

**Files:**
- Create: `src/server/RunController.luau`
- Test: `tests/RunController.spec.luau`
- Modify: `tests/run.luau` (register `RunController` suite)

**Interfaces:**
- Consumes: `RunState.new`, `RunState` instance methods (Task 6)
- Produces: `RunController.new(dependencies: {clock: () -> number, seedForPlayer: (number) -> number}) -> Controller`, `Controller:start(playerUserId: number, roster: {string})`, `Controller:submitMove(playerUserId: number, x: number, z: number) -> table`, `Controller:requestReroll(playerUserId: number) -> boolean`, `Controller:snapshot(playerUserId: number) -> table?`

- [ ] **Step 1: Write the failing test**

```lua
-- tests/RunController.spec.luau
local RunController = require("../src/server/RunController")

local cases = {}
local function case(name, body)
	table.insert(cases, { name = name, body = body })
end

local function newController()
	return RunController.new({
		clock = function()
			return 0
		end,
		seedForPlayer = function(userId)
			return userId
		end,
	})
end

case("start / creates a run and assigns a piece immediately", function()
	local controller = newController()
	controller:start(1, { "Pawn", "Knight", "Rook" })
	local snapshot = controller:snapshot(1)
	assert(snapshot ~= nil, "expected a snapshot for player 1")
	assert(snapshot.activePiece ~= nil, "a piece should be assigned on start")
end)

case("submitMove / applies a legal move and returns the result", function()
	local controller = newController()
	controller:start(1, { "Pawn" })
	local before = controller:snapshot(1)
	local destination = controller.runs[1]:legalMovesForActive()[1]
	local result = controller:submitMove(1, destination.x, destination.z)
	assert(result ~= nil, "expected a move result")
	local after = controller:snapshot(1)
	assert(after.activePosition.x ~= before.activePosition.x or after.activePosition.z ~= before.activePosition.z, "position should change")
end)

case("submitMove / unknown player is rejected", function()
	local controller = newController()
	local ok, err = pcall(function()
		controller:submitMove(999, 1, 1)
	end)
	assert(not ok, "unknown player must error: " .. tostring(err))
end)

case("requestReroll / delegates to RunState and respects the once-per-assignment limit", function()
	local controller = newController()
	controller:start(1, { "Pawn", "Knight" })
	assert(controller:requestReroll(1), "first reroll should succeed")
	assert(not controller:requestReroll(1), "second reroll on the same assignment should fail")
end)

case("snapshot / returns nil for a player with no active run", function()
	local controller = newController()
	assert(controller:snapshot(42) == nil, "expected nil for an unknown player")
end)

return function()
	for _, entry in ipairs(cases) do
		local ok, err = pcall(entry.body)
		assert(ok, entry.name .. " FAILED: " .. tostring(err))
	end
	print(string.format("RunController: PASS (%d cases)", #cases))
	return #cases
end
```

- [ ] **Step 2: Register the suite in `tests/run.luau`**

- [ ] **Step 3: Run to verify failure**

Run: `lune run tests/run.luau --filter RunController`
Expected: FAIL — module not found.

- [ ] **Step 4: Write `src/server/RunController.luau`**

```lua
-- Server-authoritative wrapper around one RunState per player. All
-- Roblox-facing code (ServerMain) talks to this, never to RunState directly.
local ReplicatedStorage = game and game:GetService("ReplicatedStorage") or nil

local RunState
if ReplicatedStorage ~= nil then
	RunState = require(ReplicatedStorage.Chess.Shared.RunState)
	local Config = require(ReplicatedStorage.Chess.Shared.Config)
	RunController_Config = Config
else
	-- Lune/test runtime: resolve relative to this file instead of `game`.
	RunState = require("../shared/RunState")
end

local Config = RunController_Config or require(if ReplicatedStorage then ReplicatedStorage.Chess.Shared.Config else "../shared/Config")

local RunController = {}
RunController.__index = RunController

function RunController.new(dependencies)
	assert(type(dependencies) == "table", "dependencies must be a table")
	assert(type(dependencies.clock) == "function", "clock must be a function")
	assert(type(dependencies.seedForPlayer) == "function", "seedForPlayer must be a function")
	return setmetatable({
		_dependencies = dependencies,
		runs = {},
	}, RunController)
end

function RunController.start(self, playerUserId: number, roster: { string })
	local seed = self._dependencies.seedForPlayer(playerUserId)
	local state = RunState.new(roster, seed, Config)
	state:assignRandomPiece()
	self.runs[playerUserId] = state
end

function RunController.submitMove(self, playerUserId: number, x: number, z: number)
	local state = self.runs[playerUserId]
	assert(state ~= nil, "no active run for player " .. tostring(playerUserId))
	return state:applyPlayerMove({ x = x, z = z })
end

function RunController.requestReroll(self, playerUserId: number): boolean
	local state = self.runs[playerUserId]
	assert(state ~= nil, "no active run for player " .. tostring(playerUserId))
	return state:reroll()
end

function RunController.snapshot(self, playerUserId: number)
	local state = self.runs[playerUserId]
	if state == nil then
		return nil
	end
	return state:snapshot()
end

return RunController
```

> ⚠ **Note for the implementer:** the `game`/`ReplicatedStorage` branch above is a placeholder for wiring into the real Rojo tree in Task 9 — Lune has no `game` global, so this module must resolve `RunState`/`Config` via relative `require` when run under `lune run tests/run.luau`, and via `ReplicatedStorage.Chess.Shared.*` when run inside Roblox. If this dual-path `require` proves awkward once Task 9 wires up `ServerMain`, simplify by having `ServerMain.server.luau` `require` the shared modules itself and pass them into `RunController.new(dependencies)` as `dependencies.RunState`/`dependencies.Config` instead — cleaner dependency injection, no runtime branching. Prefer that refactor if Task 9's wiring feels forced.

- [ ] **Step 5: Run to verify pass**

Run: `lune run tests/run.luau --filter RunController`
Expected: `RunController: PASS (5 cases)`.

- [ ] **Step 6: Commit**

```bash
git add src/server/RunController.luau tests/RunController.spec.luau tests/run.luau
git commit -m "feat: add RunController — server-authoritative per-player run wrapper"
```

---

## Task 9: EnemyAI — simple chase movement

**Files:**
- Create: `src/server/EnemyAI.luau`
- Test: `tests/EnemyAI.spec.luau`
- Modify: `tests/run.luau` (register `EnemyAI` suite)

**Interfaces:**
- Consumes: `SpawnRules.hasSafeSquare`
- Produces: `EnemyAI.planMoves(enemies: {BoardRules.Position & {health: number}}, playerPosition: BoardRules.Position, boardSize: number) -> {BoardRules.Position}` (one destination per enemy, same order as input; an enemy already adjacent to the player does not move, satisfying "적 턴 = 이동만" (PRD §6.1) since damage never happens here)

- [ ] **Step 1: Write the failing test**

```lua
-- tests/EnemyAI.spec.luau
local EnemyAI = require("../src/server/EnemyAI")

local cases = {}
local function case(name, body)
	table.insert(cases, { name = name, body = body })
end

case("planMoves / steps one square closer to the player", function()
	local enemies = { { x = 1, z = 1, health = 10 } }
	local moves = EnemyAI.planMoves(enemies, { x = 4, z = 1 }, 6)
	assert(#moves == 1, "expected one move")
	assert(moves[1].x == 2 and moves[1].z == 1, "expected a step toward the player along x")
end)

case("planMoves / already-adjacent enemy does not move", function()
	local enemies = { { x = 3, z = 3, health = 10 } }
	local moves = EnemyAI.planMoves(enemies, { x = 4, z = 3 }, 6)
	assert(moves[1].x == 3 and moves[1].z == 3, "adjacent enemy should stay put, not move")
end)

case("planMoves / never proposes a destination another enemy already occupies", function()
	local enemies = { { x = 1, z = 1, health = 10 }, { x = 2, z = 1, health = 10 } }
	local moves = EnemyAI.planMoves(enemies, { x = 6, z = 1 }, 6)
	assert(not (moves[1].x == moves[2].x and moves[1].z == moves[2].z), "two enemies must not collapse onto the same square")
end)

case("planMoves / never proposes an out-of-bounds destination", function()
	local enemies = { { x = 1, z = 1, health = 10 } }
	local moves = EnemyAI.planMoves(enemies, { x = 1, z = 1 }, 6)
	assert(moves[1].x >= 1 and moves[1].x <= 6 and moves[1].z >= 1 and moves[1].z <= 6, "destination must stay in bounds")
end)

return function()
	for _, entry in ipairs(cases) do
		local ok, err = pcall(entry.body)
		assert(ok, entry.name .. " FAILED: " .. tostring(err))
	end
	print(string.format("EnemyAI: PASS (%d cases)", #cases))
	return #cases
end
```

- [ ] **Step 2: Register the suite in `tests/run.luau`**

- [ ] **Step 3: Run to verify failure**

Run: `lune run tests/run.luau --filter EnemyAI`
Expected: FAIL — module not found.

- [ ] **Step 4: Write `src/server/EnemyAI.luau`**

```lua
-- Simple greedy chase: each enemy steps 1 square toward the player along
-- whichever axis has the larger gap (ponytail: no pathfinding, no A* --
-- MVP enemies are undifferentiated Pawn-like movers per PRD §11 scope cut).
local EnemyAI = {}

local function clampStep(delta: number): number
	if delta > 0 then
		return 1
	elseif delta < 0 then
		return -1
	end
	return 0
end

function EnemyAI.planMoves(enemies, playerPosition, boardSize: number)
	local reserved = {}
	for _, enemy in ipairs(enemies) do
		reserved[enemy.x .. "," .. enemy.z] = true
	end

	local moves = {}
	for _, enemy in ipairs(enemies) do
		local dx = playerPosition.x - enemy.x
		local dz = playerPosition.z - enemy.z
		local isAdjacent = math.abs(dx) <= 1 and math.abs(dz) <= 1
		local destination = { x = enemy.x, z = enemy.z }

		if not isAdjacent then
			local stepX, stepZ = 0, 0
			if math.abs(dx) >= math.abs(dz) then
				stepX = clampStep(dx)
			else
				stepZ = clampStep(dz)
			end
			local candidate = { x = enemy.x + stepX, z = enemy.z + stepZ }
			local inBounds = candidate.x >= 1 and candidate.x <= boardSize and candidate.z >= 1 and candidate.z <= boardSize
			local key = candidate.x .. "," .. candidate.z
			if inBounds and not reserved[key] then
				destination = candidate
			end
		end

		reserved[enemy.x .. "," .. enemy.z] = nil
		reserved[destination.x .. "," .. destination.z] = true
		table.insert(moves, destination)
	end
	return moves
end

return EnemyAI
```

- [ ] **Step 5: Run to verify pass**

Run: `lune run tests/run.luau --filter EnemyAI`
Expected: `EnemyAI: PASS (4 cases)`.

- [ ] **Step 6: Commit**

```bash
git add src/server/EnemyAI.luau tests/EnemyAI.spec.luau tests/run.luau
git commit -m "feat: add EnemyAI — greedy chase movement, no pathfinding"
```

---

## Task 10: ServerMain — wire it all into Roblox

This is the only task that touches real Roblox services (`Players`, `RemoteEvent`, `RunService`). Everything it calls has already been unit-tested in Tasks 2–9.

**Files:**
- Create: `src/server/ServerMain.server.luau`
- Modify: `default.project.json` (no change needed — `src/server` already maps to `ServerScriptService/Chess`)

**Interfaces:**
- Consumes: `RunController.new`, `RunController:start`, `RunController:submitMove`, `RunController:requestReroll`, `RunController:snapshot`, `RemoteGuard.new`, `RemoteGuard:validateMove`, `RemoteGuard:validateReroll`
- Produces: two `RemoteEvent`s under `ReplicatedStorage/Chess/Remotes` (`SubmitMove`, `RequestReroll`) and player-attribute replication of the run snapshot, matching `00_VS`'s `ensureRemoteEvent` + attribute pattern.

- [ ] **Step 1: Write `src/server/ServerMain.server.luau`**

```lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RunController = require(script.Parent.RunController)
local RemoteGuard = require(script.Parent.RemoteGuard)

local MVP_ROSTER = { "Pawn", "Knight", "Rook" }

local controller = RunController.new({
	clock = os.clock,
	seedForPlayer = function(userId)
		return userId
	end,
})
local guard = RemoteGuard.new(os.clock)

local chess = ReplicatedStorage:FindFirstChild("Chess")
if chess == nil then
	chess = Instance.new("Folder")
	chess.Name = "Chess"
	chess.Parent = ReplicatedStorage
end
local remotes = chess:FindFirstChild("Remotes")
if remotes == nil then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = chess
end

local function ensureRemoteEvent(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing ~= nil and not existing:IsA("RemoteEvent") then
		existing:Destroy()
		existing = nil
	end
	if existing == nil then
		existing = Instance.new("RemoteEvent")
		existing.Name = name
		existing.Parent = parent
	end
	return existing
end

local submitMove = ensureRemoteEvent(remotes, "SubmitMove")
local requestReroll = ensureRemoteEvent(remotes, "RequestReroll")

local function publish(player)
	local snapshot = controller:snapshot(player.UserId)
	if snapshot == nil then
		return
	end
	player:SetAttribute("ActivePiece", snapshot.activePiece)
	player:SetAttribute("ActiveHealth", snapshot.activeHealth)
	player:SetAttribute("ActiveMaxHealth", snapshot.activeMaxHealth)
	player:SetAttribute("Level", snapshot.level)
	player:SetAttribute("PositionX", snapshot.activePosition.x)
	player:SetAttribute("PositionZ", snapshot.activePosition.z)
	player:SetAttribute("RosterCount", #snapshot.roster)
	player:SetAttribute("EnemyCount", #snapshot.enemies)
end

submitMove.OnServerEvent:Connect(function(player, ...)
	local packed = table.pack(...)
	local snapshot = controller:snapshot(player.UserId)
	local validated = guard:validateMove(player.UserId, {
		argc = select("#", ...),
		args = packed,
	}, { phase = snapshot ~= nil and "Turn" or "NoRun" })
	if not validated.accepted then
		warn(string.format("[CHESS_SECURITY] rejected SubmitMove reason=%s", validated.reason))
		return
	end
	local ok, err = pcall(function()
		controller:submitMove(player.UserId, packed[1], packed[2])
	end)
	if not ok then
		warn(string.format("[CHESS_SECURITY] SubmitMove failed: %s", tostring(err)))
		return
	end
	publish(player)
end)

requestReroll.OnServerEvent:Connect(function(player, ...)
	local packed = table.pack(...)
	local snapshot = controller:snapshot(player.UserId)
	local validated = guard:validateReroll(player.UserId, {
		argc = select("#", ...),
		args = packed,
	}, { phase = snapshot ~= nil and "Turn" or "NoRun" })
	if not validated.accepted then
		warn(string.format("[CHESS_SECURITY] rejected RequestReroll reason=%s", validated.reason))
		return
	end
	controller:requestReroll(player.UserId)
	publish(player)
end)

Players.PlayerAdded:Connect(function(player)
	controller:start(player.UserId, MVP_ROSTER)
	publish(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	controller:start(player.UserId, MVP_ROSTER)
	publish(player)
end
```

- [ ] **Step 2: Build and smoke-test in Studio**

Run:
```bash
cd 01_Chess
rojo build default.project.json -o build/Chess.rbxlx
```
Expected: build succeeds with no errors. Open `build/Chess.rbxlx` in Roblox Studio, press Play — a player should join and immediately have `ActivePiece`/`ActiveHealth`/`Level`/etc. attributes populated (visible via the Properties/Attributes panel), matching one of `Pawn`/`Knight`/`Rook`.

- [ ] **Step 3: Commit**

```bash
git add src/server/ServerMain.server.luau
git commit -m "feat: add ServerMain — wire RunController/RemoteGuard to Players and RemoteEvents"
```

---

## Task 11: Full test suite pass and lint

**Files:** none created; this task only runs verification across everything built in Tasks 1–10.

- [ ] **Step 1: Run the complete Lune test suite**

Run: `cd 01_Chess && lune run tests/run.luau`
Expected: every suite prints `PASS`, ending in `TEST SUMMARY: PASS (N named cases)` where N is the sum of all suites (4 + 8 + 5 + 6 + 11 + 6 + 5 + 4 = 49).

- [ ] **Step 2: Lint with selene**

Run: `selene src/`
Expected: no errors (warnings from the `empty_if` rule are acceptable per `selene.toml`).

- [ ] **Step 3: Format-check with stylua**

Run: `stylua --check src/ tests/`
Expected: no diffs. If it reports diffs, run `stylua src/ tests/` and re-run the check.

- [ ] **Step 4: Final commit if formatting changed anything**

```bash
git add -A
git commit -m "chore: stylua formatting pass"
```

---

## What's Deliberately Out of Scope Here

- **Client presentation** (board rendering, click-to-move input, damage-preview UI, HUD) — needs its own plan once this engine is stable, since it's verified by manual Studio play rather than `lune run tests/run.luau`.
- **The 3 MVP measurement hooks** (restart-after-loss, rounds/session, D1/D7) — needs an analytics/logging decision (which service, what event shape) that the PRD doesn't specify; belongs in the same follow-up plan as the client.
- **Currency/DataStore persistence and piece purchase** (PRD §6.3) — this plan's `RunController` is in-memory only; persistence is a distinct concern (schema, save-on-leave, migration) worth its own task list once the core loop is proven fun enough to be worth persisting progress in.
- **Bishop/Queen/King, piece-tier escalation, King-clear, transcendence, permanent upgrades** — all explicitly v1 per PRD §11/§6.6, not touched by this plan.

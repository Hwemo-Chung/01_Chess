# 01_Chess — Roblox Chess-Piece Roguelike

Standalone project. Unrelated to `00_VS` (do not touch `00_VS`).

**Status:** MVP core engine implemented (pure rules + server orchestration). Client presentation is out of scope for this slice.

## What it is

PvE roguelike where the player **is** a chess piece. Owned pieces are lives; which piece you fight as is randomly assigned (1 reroll). Turn-based movement on a fixed 6×6 board; combat resolves automatically with crit/pierce.

MVP piece set: **Pawn / Knight / Rook**.

## Layout

```
src/shared/   pure Luau rules (no Roblox deps) — Config, Rng, BoardRules, CombatRules, SpawnRules, RunState
src/server/   RemoteGuard, RunController, EnemyAI, ServerMain.server.luau
tests/        Lune unit suites (hand-rolled case/expect)
docs/         PRD, BENCHMARK, implementation plan
```

## Toolchain

Pinned via `rokit.toml` (same as `00_VS`): Rojo 7.7.0, Lune 0.10.5, Selene 0.31.0, StyLua 2.5.2.

```bash
export PATH="$HOME/.rokit/bin:$PATH"
# from this directory (needs rokit.toml present)
lune --version && rojo --version
```

## Commands

```bash
export PATH="$HOME/.rokit/bin:$PATH"

# unit tests
lune run tests/run.luau
lune run tests/run.luau -- --filter RunState

# lint / format
selene src/
stylua --check src/ tests/

# build place file for Studio
mkdir -p build && rojo build default.project.json -o build/Chess.rbxlx
```

Or via npm scripts (`npm test`, `npm run build`, `npm run lint`) with the same PATH.

## Studio smoke

1. `rojo build default.project.json -o build/Chess.rbxlx`
2. Open in Roblox Studio → Play
3. Player attributes should populate: `ActivePiece`, `ActiveHealth`, `Level`, `PositionX`/`PositionZ`, `EnemyCount`, etc.
4. Remotes under `ReplicatedStorage.Chess.Remotes`: `SubmitMove(x, z)`, `RequestReroll()`

## Docs

- [PRD](docs/PRD.md) — product definition v1.0
- [BENCHMARK](docs/BENCHMARK.md) — Roblox market measurements
- [MVP plan](docs/superpowers/plans/2026-07-24-mvp-core-engine.md) — task breakdown this build follows

## Out of scope (next plan)

Client board rendering / click-to-move / damage-preview UI / HUD, analytics hooks (restart-after-loss, rounds/session, D1/D7), DataStore persistence & piece shop, Bishop/Queen/King & prestige.

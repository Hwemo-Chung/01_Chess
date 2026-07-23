# 01_Chess — Roblox Chess-Piece Roguelike

Standalone project. Unrelated to `00_VS` (do not touch `00_VS`).

**Status:** MVP core engine + playable client presentation (Studio).

## What it is

PvE roguelike where the player **is** a chess piece. Owned pieces are lives; which piece you fight as is randomly assigned (1 reroll). Turn-based movement on a fixed 6×6 board; combat resolves automatically with crit/pierce.

MVP piece set: **Pawn / Knight / Rook**.

## Play (Studio)

```bash
export PATH="$HOME/.rokit/bin:$PATH"
mkdir -p build && rojo build default.project.json -o build/Chess.rbxlx
# Open build/Chess.rbxlx → Play
```

| Input | Action |
|-------|--------|
| Click green square | Move |
| Click red square | Attack (capture-and-land if kill) |
| **Reroll** button | Once per assignment |
| **Restart Run** | After roster exhausted |

Server remotes under `ReplicatedStorage.Chess.Remotes`:
`SubmitMove`, `RequestReroll`, `RequestRestart`, `StateSync` (server → client snapshot).

## Layout

```
src/shared/   pure Luau — Config, Rng, BoardRules, CombatRules, SpawnRules, RunState, BoardLayout
src/server/   RemoteGuard, RunController, EnemyAI, ServerMain.server.luau
src/client/   BoardView, CameraController, HudController, GameClient.client.luau
tests/        Lune unit suites
docs/         PRD, BENCHMARK, implementation plan
```

## Commands

```bash
export PATH="$HOME/.rokit/bin:$PATH"
lune run tests/run.luau
selene src/
stylua --check src/ tests/
npm test   # same as lune run tests/run.luau when PATH has tools
```

## Docs

- [PRD](docs/PRD.md) — product definition v1.0
- [BENCHMARK](docs/BENCHMARK.md) — Roblox market measurements
- [MVP engine plan](docs/superpowers/plans/2026-07-24-mvp-core-engine.md)

## Still out of scope

Damage-preview UI polish, analytics hooks (restart-after-loss / rounds / D1-D7), DataStore + piece shop, Bishop/Queen/King + prestige.

# 01_Chess — Roblox Chess-Piece Roguelike

Standalone project. Unrelated to `00_VS` (do not touch `00_VS`).

**Status:** Playable MVP — core engine, client, damage preview, metrics, shop/profile, full 6 pieces.

## Loop

1. Random piece from **roster lives** (1 reroll)
2. Turn-based move on **6×6** — combat auto-resolves (crit / pierce / frailty)
3. Enemies chase after your move
4. Die → next random life; roster empty → run over → gold + shop → restart

## Pieces

| Piece | Move | Ability |
|-------|------|---------|
| Pawn | 1 orthogonal | baseline |
| Knight | L-jump | 30% crit |
| Bishop | diagonal, blocked | distance crit up to 30%; same-color enemy spawn |
| Rook | orthogonal, blocked | pierce second enemy on kill |
| Queen | all slides, blocked | take ×1.5 damage |
| King | 1-adjacent | take ×0.5 damage |

## Studio

```bash
export PATH="$HOME/.rokit/bin:$PATH"
rojo build default.project.json -o build/Chess.rbxlx
```

| Input | Action |
|-------|--------|
| Green tile | Move |
| Red / bright red tile | Attack (preview billboard shows hit/take/kill%) |
| Reroll | Once per assignment |
| Shop (game over) | Buy extra lives with gold |
| Restart | New run (counts restart-after-loss) |

## Remotes (`ReplicatedStorage.Chess.Remotes`)

`SubmitMove` · `RequestReroll` · `RequestRestart` · `RequestBuy` · `StateSync`

## Layout

```
src/shared/   Config, Rng, BoardRules, CombatRules, SpawnRules, RunState, BoardLayout, ProfileRules, Metrics
src/server/   RemoteGuard, RunController, EnemyAI, ProfileStore, ServerMain
src/client/   BoardView, CameraController, HudController, GameClient
tests/        Lune suites
```

## Verify

```bash
export PATH="$HOME/.rokit/bin:$PATH"
lune run tests/run.luau
selene src/
stylua --check src/ tests/
```

## Metrics (PRD §3.2)

Server prints `[CHESS_METRICS]` each run end:

- **restart-after-loss** rate (`restartsAfterLoss / runsEnded`)
- **rounds per session**
- Profile counters persist via DataStore `ChessProfiles_v1` (gold, roster, best level)

D1/D7 needs multi-day login tracking (profile ready; external analytics later).

## Docs

- [PRD](docs/PRD.md) · [BENCHMARK](docs/BENCHMARK.md) · [engine plan](docs/superpowers/plans/2026-07-24-mvp-core-engine.md)

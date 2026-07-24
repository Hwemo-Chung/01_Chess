# 01_Chess — Roblox Chess-Piece Roguelike

Standalone project. Unrelated to `00_VS`.

**Status:** Playable v1 loop — engine, client, shop, permanent upgrades, enemy tier ladder, King-clear victory, transcendence.

## Core loop

1. Random piece from roster lives (1 reroll) · permanent upgrades apply to all pieces
2. Turn-based move on 6×6 · combat auto (crit / pierce / frailty)
3. Enemies chase with their own piece movesets
4. Levels: enemy **count** ramps to cap → **tier** climbs Pawn→King
5. **King boss** kill = Victory (mutual-KO: victory wins) · roster empty = defeat
6. Shop (lives + Might/Vitality) → Restart same T, or **Transcend** (+T enemy scaling)

## Difficulty ladder (PRD §6.2)

| Levels | What changes |
|--------|----------------|
| 1–12 | Enemy count 1→12, tier Pawn |
| 13–16 | Count capped, tier Knight→Queen |
| 17+ | King **boss** + Queen minions |

Transcendence uses a **soft curve** (not raw ×T): HP +0.50/step, ATK +0.35/step
(T1=1, T2≈1.5/1.35, T3≈2.0/1.7). Abilities unscaled. See `Transcendence.luau`.

## Pieces

| Piece | Move | Ability |
|-------|------|---------|
| Pawn | 1 orthogonal | baseline |
| Knight | L-jump | 30% crit |
| Bishop | diagonal, blocked | distance crit ≤30%; same-color spawn |
| Rook | orthogonal, blocked | pierce on kill |
| Queen | all slides | take ×1.5 |
| King | 8-adjacent | take ×0.5 |

## Studio

```bash
export PATH="$HOME/.rokit/bin:$PATH"
rojo build default.project.json -o build/Chess.rbxlx
```

Remotes: `SubmitMove` · `RequestReroll` · `RequestRestart` · `RequestBuy` · `RequestBuyUpgrade` · `RequestTranscend` · `StateSync`

## Verify / Sim / Build

```bash
export PATH="$HOME/.rokit/bin:$PATH"
lune run tests/run.luau
lune run scripts/balance_sim.luau -- --runs 50
# report → docs/BALANCE_SIM.md

mkdir -p build && rojo build default.project.json -o build/Chess.rbxlx
# open build/Chess.rbxlx in Roblox Studio → Play
```

## Docs

[PRD](docs/PRD.md) · [BENCHMARK](docs/BENCHMARK.md) · [engine plan](docs/superpowers/plans/2026-07-24-mvp-core-engine.md)

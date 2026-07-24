# 01_Chess — 세션 핸드오프

**작성** 2026-07-24 · **브랜치** `main` · **HEAD** 아래 git log 기준  
**저장소** https://github.com/Hwemo-Chung/01_Chess  
**커밋 작성자 고정** `Chung Hwemo <tolaria@naver.com>` (Author + Committer 모두)

> `00_VS` 미접촉. 이 폴더(`01_Chess/`)만 작업.

---

## 1. 한 줄 상태

**플레이 가능한 v1 루프 구현됨** — pure 규칙 엔진 + 서버 권위 + Studio 클라 + 상점/강화/초월 + 밸런스 시뮬.  
Studio Play 시 **초기 StateSync 유실** 문제를 `RequestStateSync` + 재전송으로 수정함 (`ded614c`). **반드시 최신 `build/Chess.rbxlx`로 재빌드 후 플레이.**

**[2026-07-24 에셋 P0]** `IconAssets` 단일 키 + `IconPixelPack`(64² 임베드) + `IconSurface`(cloud→asphalt→픽셀).  
**asphalt 없이** Studio Play에서도 아이콘 표시 (EditableImage).  
클라우드: `IconAssets` CLOUD 숫자 기입. 검증: `npm run verify` + `docs/OWNER-LIVE-QA.md`.

**[2026-07-24 아이콘 버그픽스]** Roblox 엔진은 문자열 require 미지원 — `IconAssets`/`IconPixels`의
`require("./…")`가 pcall에 조용히 삼켜져 아이콘 3단 폴백 전멸(텍스트만 표시)했던 버그 수정.
`script ~= nil` 분기로 Roblox=인스턴스 require / Lune=문자열 require. **shared 신규 모듈도 이 패턴 필수.**

**[2026-07-24~25 타격감/UIUX 패키지]** `src/client/Fx.luau` 신규 + BoardView/GameClient/HudController 배선.
근거·매핑표: `docs/JUICE_BENCHMARK.md`. **서버/엔진 무변경, 테스트 141 PASS 유지.**

- **전투 시퀀스 (오너 지시)**: 방어(피격) 즉시 → **1초 후** 공격 처리. 동시 재생 금지.
- **사운드 (오너 지시)**: 공격·피격 둘 다 폭발음(`impact_explosion_03`, 공격 1.3x 고음 / 피격 0.8x 저음).
  목소리류(ouch/oof) 금지. 처치는 파티클+셰이크만. 이동 착지음, 업그레이드/기물 구매 성공음.
  **내장 사운드는 11개 파일뿐** — 클래식(swordslash 등) 없음. `content/sounds/` 실존 확인 필수.
- **모션**: 말 이동 = 포물선 arcMove(Knight 고점 4, 그 외 1). 적 이동도 파트 재사용 매칭으로 애니메이션.
  **공격 런지**: 플레이어 말 대상 칸으로 대시-복귀, 적 반격/적 페이즈도 런지 (`Fx.lunge`, 홈 복귀 보장).
  스폰 스케일-인, 사망 축소-페이드.
- **이펙트**: 데미지 플로팅 텍스트(크리 주황 대형), 처치 fire+smoke 이중 버스트, 크리 sparkles,
  클릭 즉시 핑, 적 피격 Highlight 플래시, 적 HP바(최고 관측치로 max 추정), 하이라이트 숨쉬기 펄스,
  카메라 감쇠 셰이크, 피격 빨간 풀스크린 플래시, HUD HP/Gold 펄스, 버튼 hover/press.
- **아바타 숨김**: 액세서리 늦은 로드도 DescendantAdded로 숨김.
- QA 절차: `build/ChessQA.rbxlx` 사본으로 Studio 자동 오픈(`open`) — 본 파일 잠금 회피.

---

## 2. 제품 요약 (PRD v1.0)

| 항목 | 내용 |
|------|------|
| 장르 | PvE 체스말 로그라이크 (1기 전투, 보유 말 = 목숨) |
| 보드 | 6×6 고정 |
| 조작 | 턴제 이동 선택, 전투 자동 |
| MVP 가설 | “랜덤 배정 1기로 싸우는 재미가 재플레이를 만드는가?” |
| 승리 | King 보스 처치 (`phase=Victory`) |
| 패배 | 로스터 소진 (`phase=GameOver`) |
| 수익화 | 아직 없음 (코스메틱 전용 설계는 PRD §8, 미구현) |

근거·결정: `docs/PRD.md`, 시장 실측: `docs/BENCHMARK.md`

---

## 3. 구현된 것 (체크리스트)

### 3.1 코어 엔진 (`src/shared/`, Lune 테스트 가능)

- [x] `Config` — 보드/적/기물/강화/초월 상수
- [x] `Rng` — 시드 PRNG (Park-Miller)
- [x] `BoardRules` — Pawn/Knight/Bishop/Rook/Queen/King 합법수 + BLOCKED
- [x] `CombatRules` — crit, Rook pierce, Bishop 거리 crit, 데미지 프리뷰
- [x] `SpawnRules` — 적 수 캡, safe square, **티어 사다리**
- [x] `RunState` — 턴/전투/목숨/레벨/보스 클리어/mutual-KO(보스 우선)
- [x] `ProfileRules` — 골드, 로스터 구매, Might/Vitality, 초월, 런 정산
- [x] `Metrics` — restart-after-loss, rounds/session
- [x] `Transcendence` — soft HP/ATK 곡선 (raw ×T 아님)
- [x] `BoardLayout` — 그리드↔월드 좌표
- [x] `SimAI` / `SimEnemy` — 오프라인 밸런스 시뮬 정책

### 3.2 서버 (`src/server/`)

- [x] `RunController` — 플레이어별 RunState
- [x] `RemoteGuard` — move/reroll/restart/buy/transcend rate limit
- [x] `EnemyAI` — 기물별 추적 + Knight L-ring 고정/인접 회피
- [x] `ProfileStore` — DataStore 또는 Studio 메모리
- [x] `ServerMain.server.luau` — remotes, 턴 루프, 상점, 초월, **StateSync 재동기화**

### 3.3 클라이언트 (`src/client/`)

- [x] `BoardView` — 6×6, 말, 적, 합법수 하이라이트, 데미지 프리뷰 빌보드
- [x] `CameraController` — 탑다운 Scriptable
- [x] `HudController` — HP/레벨/티어/골드/T, 리롤, 상점, Restart/Transcend
- [x] `GameClient.client.luau` — 클릭 이동, remotes, RequestStateSync 폴링

### 3.4 도구·문서

- [x] Rojo / rokit / Lune / Selene / StyLua
- [x] `scripts/balance_sim.luau` → `docs/BALANCE_SIM.md`
- [x] 단위 테스트 **80 cases** (`lune run tests/run.luau`)
- [x] 엔진 플랜: `docs/superpowers/plans/2026-07-24-mvp-core-engine.md` (구현 완료 수준)

---

## 4. 핵심 룰 / 밸런스 (현행 수치)

### 난이도 사다리

| 레벨 | 내용 |
|------|------|
| 1–12 | 적 수 1→12, 티어 Pawn |
| 13–16 | 수 캡, Knight→Queen 티어 |
| 17+ | King **보스 1** + Queen 잡몹 |

### 스탯 (플레이스홀더, 시뮬로 튜닝됨)

- 적 base: HP **6**, ATK **1** (`ENEMY_BASE`) — **플레이어 PIECES 테이블을 적 HP에 쓰지 말 것** (버그였음)
- 티어 배율: `1 + 0.12*(index-1)`
- 초월 soft: HP +0.50/step, ATK +0.35/step, 보스 cushion × soft extra  
  → T1=1, T2≈1.5/1.35, T3≈2.0/1.7
- 시작 로스터: Pawn, Knight, Rook
- 강화: Might/Vitality 각 +6%/레벨, 가격 15g

### 시뮬 요약 (최근 40런, greedy AI)

| 시나리오 | 결과 |
|----------|------|
| solo 3목숨 T1 | avg Lv ~12–15, King 클리어 0% (목숨 부족) |
| roster full6 T1 | **~72% win** |
| Rook×8 T1 | **100% win** |
| Rook×3 M10V10 T1 | **~55% win** |
| Rook×8 M15V15 T3 | **100% win** (soft 초월 후) |
| Rook×3 T1→T3 avgLv | 13 → 9 → 6 (벽은 남김) |

상세: `docs/BALANCE_SIM.md` (재생성: `lune run scripts/balance_sim.luau -- --runs 40`)

---

## 5. 아키텍처

```
Client                          Server                         Shared (pure)
──────                          ──────                         ─────────────
GameClient ──SubmitMove──────►  ServerMain                     RunState
           ◄──StateSync────────   RunController ──►            BoardRules
           ──RequestStateSync──   EnemyAI                      CombatRules
BoardView / Hud / Camera          ProfileStore                 Config, Rng
                                  RemoteGuard                  ProfileRules
                                                               Transcendence
```

- **진실 소스**: 서버 RunState. 클라는 스냅샷만 렌더.
- **Remotes** (`ReplicatedStorage.Chess.Remotes`):
  - `SubmitMove(x,z)`, `RequestReroll`, `RequestRestart`
  - `RequestBuy(piece)`, `RequestBuyUpgrade(id)`, `RequestTranscend`
  - `StateSync` (S→C), `RequestStateSync` (C→S, 초기 동기화)

---

## 6. 실행 방법

```bash
export PATH="$HOME/.rokit/bin:$PATH"
cd /path/to/01_Chess

# 테스트
lune run tests/run.luau

# 밸런스 시뮬
lune run scripts/balance_sim.luau -- --runs 40

# Studio place
mkdir -p build && rojo build default.project.json -o build/Chess.rbxlx
# Studio에서 build/Chess.rbxlx 열기 → Play
# Output에 [CHESS] 로그 확인:
#   ServerMain starting / GameClient starting / StateSync connected
#   snapshot phase=Turn piece=... enemies=...
```

**Play 시 기대 UI**

- 6×6 체스판 + 파란 플레이어 말 + 빨간 적
- 초록(이동)/빨강(공격) 하이라이트 + 데미지 프리뷰 텍스트
- 좌상단 HUD, 클릭으로 이동

판만 보이면: **옛 rbxlx**이거나 동기화 실패 → 재빌드 + Output `[CHESS]` 확인.

---

## 7. 수정했던 중요 버그 (재발 금지)

1. **StateSync 레이스** — 클라 리스너 전에 FireClient → 빈 판.  
   → `RequestStateSync` + delayed re-publish (`ded614c`)
2. **적 스탯이 플레이어 PIECES 공유** — 조기 전멸.  
   → `ENEMY_BASE` + 티어 소배율만 (`8499aa1`)
3. **마지막 적 처치 + 동시 사망 시 레벨 미진행**  
   → 보드 클리어를 목숨 처리보다 먼저 (`6f97ca8`)
4. **Knight 소프트락** — 인접 주차 / L칸 이탈  
   → 캡처 불가 인접 회피 + L-ring freeze (`8499aa1`)
5. **초월 raw ×T** — T3 벽 과다  
   → soft HP/ATK 분리 (`4e1b47b`)

---

## 8-1. 다음 세션 작업 지침 — 에셋 적용 (최우선, 2026-07-24 지정)

**단일 소스**: `docs/PRD_ASSET_INTEGRATION.md`. 아래는 실행 순서 요약.

### 첫 블로커

**`rbxassetid`는 유저 Studio Bulk Import 필요.** 에이전트가 ID를 만들 수 없음.  
→ 유저에게 업로드 요청 → ID 수령 전: **폴백 구조(`ASSET_IDS` 전부 `0` + `iconOrText`)까지만** 구현 후 대기. ID 꽂는 커밋은 수령 후.

### 금지 사항 (위반 시 즉시 롤백)

| 금지 | 이유 |
|------|------|
| `src/server/**` 수정 | 서버/엔진 변경 0 — 테스트 80 무영향 유지 |
| `src/shared/**` 중 Config 외 수정 | pure 규칙 엔진 불변 |
| TextButton → ImageButton 교체 | 레이아웃 붕괴 방지. **ImageLabel 삽입만** |
| 3D 보드 기물 메시/텍스처 교체 | PRD out of scope |
| Open Cloud API 업로드 자동화 | 안 B 배제 (과설계) |

### 실행 순서

1. **시작 절차** §11 그대로 (pull → 테스트 80 PASS).
2. `assets/images/` 26장 확인 (`ls assets/images \| wc -l` → 26).
3. **작업 1 (유저)**: Studio Asset Manager → Bulk Import 26장 → ID를 PRD §7 기록표 기입.
4. **작업 2–5** PRD §6 커밋 단위:
   - `Config.ASSET_IDS` + `iconOrText` 폴백 (ID `0` = 텍스트, PRD §4.1)
   - HUD 스탯/버튼 → 상점/로스터 → 크리 + 보스 배너
5. 각 커밋 전: `lune run tests/run.luau` + Selene + `rojo build` + Studio Play 육안 (AC = PRD §5).
6. 게임 아이콘/썸네일: Roblox 게임 설정에서 유저 직접 업로드 (코드 외).
7. 완료 시 PRD §7 체크박스 + 본 문서 §1 상태 줄 갱신.

## 8. 의도적 미구현 / 다음 작업 후보

우선순위는 제품 목표에 맞게 고를 것.

| 우선 | 항목 | 메모 |
|------|------|------|
| A | **수동 Studio QA 체크리스트 통과 확인** | 말/HUD/리롤/사망/상점/초월 E2E |
| A | **D1/D7 계측** | Metrics는 세션만; 로그인 일자 영속 + AnalyticsService 또는 자체 로그 |
| B | **코스메틱 수익화** | PRD §8–9, GamePass/DevProduct, PolicyService |
| B | **Pawn 승급 트리거** | PRD §6.4 미정 항목 |
| B | **밸런스 재튜닝** | Queen avgLv 낮음, 3목숨 King 클리어율 등 |
| C | **적도 플레이어 특수능력 완전 대칭** | 현재 이동+incoming mult 중심 |
| C | **클라 폴리시** | 데미지 숫자 팝업, 사운드, 보드 스킨 |
| C | **DataStore 프로덕션 hardening** | 세션 락, 스키마 마이그레이션 (00_VS 패턴 참고 가능, 코드 복사 금지 권장) |

PRD open items §12 (결정론 시뮬 항목 일부는 `balance_sim`으로 착수됨).

---

## 9. 주요 커밋 타임라인 (구현기)

```
abfe063  feat: MVP core engine
a45e6d9  feat: client board/HUD
0ed4e67  feat: preview, metrics, shop, 6 pieces
3b5cbce  feat: tiers, King clear, upgrades, transcendence
6f97ca8  feat: balance sim + level-clear fix
8499aa1  fix: stats retune + Knight softlock
4e1b47b  balance: soft transcendence curve
ded614c  fix: StateSync resync (empty board)
2d6e0c5  chore: ignore .DS_Store
b1e8a5a  assets: image prompts + 26 generated PNGs
8e11284  docs: PRD_ASSET_INTEGRATION + handoff §8-1
```

---

## 10. 파일 맵

```
01_Chess/
├── default.project.json      # Rojo → SSS/Chess, RS/Chess/Shared, SPS/Chess
├── rokit.toml / package.json
├── assets/images/            # 26 PNG (생성 완료, rbxassetid 미업로드)
├── src/shared/               # pure Luau — Config.ASSET_IDS 추가 예정
├── src/server/               # ServerMain + controllers (에셋 작업 시 수정 금지)
├── src/client/               # GameClient + HudController + BoardView
├── tests/                    # Lune unit suites (80 cases)
├── scripts/balance_sim.luau
├── docs/
│   ├── PRD.md
│   ├── PRD_ASSET_INTEGRATION.md  # 에셋 적용 PRD (다음 작업 단일 소스)
│   ├── ASSET_PROMPTS.md
│   ├── BENCHMARK.md
│   ├── BALANCE_SIM.md
│   ├── SESSION_HANDOFF.md    # 본 문서
│   └── superpowers/plans/…
└── build/Chess.rbxlx         # gitignore 대상일 수 있음 — 로컬 빌드
```

---

## 11. 다음 세션 시작 절차 (복붙)

1. `cd …/01_Chess && git pull && git log -3 --oneline`
2. 본 문서 + `docs/PRD_ASSET_INTEGRATION.md` 확인
3. `export PATH="$HOME/.rokit/bin:/opt/homebrew/bin:$PATH"`
4. `asphalt sync studio` — Studio content에 이미지 복사 (아이콘 실표시 필수)
5. `lune run tests/run.luau` → 100+ PASS
6. `rojo build default.project.json -o build/Chess.rbxlx` → Studio Play
7. 커밋 시 **항상** `Chung Hwemo <tolaria@naver.com>` (Author+Committer)

---

## 12. 종료 시점 검증

| 항목 | 상태 |
|------|------|
| 단위 테스트 | 80 PASS |
| Selene | 0 errors (직전 세션) |
| 시뮬 리포트 | `docs/BALANCE_SIM.md` 존재 |
| Play 빈 판 이슈 | 수정 커밋됨 — 최신 빌드로 수동 확인 권장 |
| 에셋 PNG 26장 | `assets/images/` 존재 (`b1e8a5a`) |
| 에셋 적용 PRD | `docs/PRD_ASSET_INTEGRATION.md` (코드 적용 전) |
| rbxassetid | **미확보** — 다음 세션 첫 블로커 (유저 Studio 업로드) |

**세션 종료.** 커밋 안 함 (명시 요청 없음). 다음 세션: 로컬 diff 있으면 `git add docs/` 후 커밋 판단.

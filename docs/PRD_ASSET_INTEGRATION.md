# PRD — 이미지 에셋 게임 적용 (Asset Integration v1)

**작성** 2026-07-24 · **선행** `docs/ASSET_PROMPTS.md` (26장 생성 완료, `assets/images/`)
**목표**: 텍스트 전용 HUD를 아이콘 기반 UI로 전환. 게임플레이 로직 변경 0.

---

## 1. 배경 / 현황

- `assets/images/` 26장 존재 (기물 12, 보스 1, 강화 2, HUD 8, 스토어 3).
- 현재 `HudController.luau` 전부 TextLabel/TextButton — 이미지 사용 없음.
- `Config.luau`에 에셋 ID 테이블 없음.
- 보드 기물은 3D Part — 이 PRD 범위 아님 (아이콘은 UI 전용).

## 2. 범위

### In scope

| 구분 | 적용 위치 | 사용 에셋 |
|------|-----------|-----------|
| HUD 스탯 아이콘 | hpLabel, currencyLabel, metaLabel 앞 | `icon_hp`, `icon_atk`, `icon_gold`, `icon_level` |
| 액션 버튼 | reroll/restart/transcend 버튼 | `icon_reroll`, `icon_restart`, `icon_transcend` |
| 상점 — 기물 구매 | 기물별 구매 버튼 | `piece_*_blue` 6종 |
| 상점 — 강화 | Might/Vitality 버튼 | `upgrade_might`, `upgrade_vitality` |
| 로스터(목숨) 표시 | livesHeader 아래 목숨 리스트 | `piece_*_blue` 6종 |
| 데미지 프리뷰 | 크리 표시 빌보드 | `icon_crit` |
| 보스 조우 배너 | 레벨 17 진입 시 1회 표시 (신규 소형 UI) | `boss_king` |
| 적 티어 표시 | HUD 티어 라벨 옆 | `piece_*_red` (현재 티어 기물) |
| 스토어 자산 | Roblox 게임 설정 (코드 외) | `game_icon`, `thumbnail_*` |

### Out of scope

- 보드 위 3D 기물 메시/텍스처 교체.
- 사운드, 파티클, 애니메이션.
- 코스메틱 수익화 (기존 PRD §8 별도).

## 3. 업로드 파이프라인 (결정 필요 → 기본안 A)

| 안 | 방법 | 비고 |
|----|------|------|
| **A (기본)** | Studio Asset Manager → Bulk Import 26장 → rbxassetid 수동 기록 | 수동이지만 확실. 1회성 |
| B | Open Cloud Assets API (`rbxcloud` CLI) 스크립트 업로드 | API 키 필요, 자동화 가능. 26장에 과설계 |

**결정**: A. 업로드 후 ID를 `Config.ASSET_IDS`에 기록.
**제약**: 이미지 모더레이션 통과 필수 — 업로드 후 상태 확인. 실패 시 해당 슬롯 `0` 유지(폴백 동작).

## 4. 설계

### 4.1 Config.ASSET_IDS (신규, `src/shared/Config.luau`)

```lua
Config.ASSET_IDS = {
	pieces = { -- [pieceName] = { blue = id, red = id }
		Pawn = { blue = 0, red = 0 },
		Knight = { blue = 0, red = 0 },
		Bishop = { blue = 0, red = 0 },
		Rook = { blue = 0, red = 0 },
		Queen = { blue = 0, red = 0 },
		King = { blue = 0, red = 0 },
	},
	upgrades = { Might = 0, Vitality = 0 },
	icons = { hp = 0, atk = 0, gold = 0, level = 0, crit = 0,
		reroll = 0, restart = 0, transcend = 0 },
	boss = { king = 0 },
}
```

- ID `0` = 미업로드/모더레이션 실패 → **텍스트 폴백** (현행 UI 유지). 신규 헬퍼 하나로 처리:

```lua
-- HudController 내부
local function iconOrText(parent, assetId, fallbackText, props) ... end
```

### 4.2 HudController 변경

- TextButton → ImageButton 교체 **하지 않음**. 기존 버튼 유지 + 좌측 ImageLabel 삽입 (레이아웃 리스크 최소화).
- 상점 기물/강화 버튼: 버튼 내 ImageLabel(좌) + 기존 텍스트(우).
- 보스 배너: `phase` 스냅샷에서 레벨 17 최초 진입 감지 → 2초 표시 후 소멸. 클라 전용, 서버 변경 없음.

### 4.3 BoardView 변경

- 데미지 프리뷰 빌보드: 크리 가능 시 `icon_crit` ImageLabel 추가. 그 외 변경 없음.

### 4.4 서버/엔진 변경

- **없음.** pure 엔진·서버·remotes 무변경. 단위 테스트 80 케이스 영향 0.

## 5. 수용 기준 (AC)

1. Studio Play: HUD 스탯 4종 아이콘 표시, 텍스트 수치 유지.
2. 리롤/재시작/초월 버튼에 아이콘 표시, 클릭 동작 기존과 동일.
3. 상점 열기: 기물 6종 + 강화 2종 버튼에 아이콘 표시, 구매 동작 동일.
4. 로스터 목숨 리스트에 기물 아이콘 표시.
5. 레벨 17 진입 시 보스 배너 1회 표시.
6. `ASSET_IDS` 전부 `0`인 상태에서도 기존 텍스트 UI로 정상 동작 (폴백 검증).
7. `lune run tests/run.luau` 80 PASS 유지.
8. Selene 0 errors.

## 6. 작업 분해 (권장 커밋 단위)

| # | 작업 | 산출물 |
|---|------|--------|
| 1 | Studio Bulk Import 26장, ID 기록 | ID 목록 (본 문서 §7에 기입) |
| 2 | `Config.ASSET_IDS` + 폴백 헬퍼 | commit `feat: asset id registry` |
| 3 | HUD 스탯/버튼 아이콘 | commit `feat: hud icons` |
| 4 | 상점/로스터 아이콘 | commit `feat: shop & roster icons` |
| 5 | 크리 아이콘 + 보스 배너 | commit `feat: crit icon & boss banner` |
| 6 | 게임 아이콘/썸네일 업로드 (Roblox 설정) | 코드 외, §7에 완료 체크 |
| 7 | Studio E2E QA (AC 1–6) + 테스트/린트 | 검증 로그 |

## 7. 업로드 ID 기록 (작업 1에서 채울 것)

```
piece_pawn_blue   = rbxassetid://________
piece_knight_blue = rbxassetid://________
... (26장 전부)
```

- [ ] 26장 업로드 완료
- [ ] 모더레이션 전부 통과
- [ ] game_icon / thumbnail 게임 설정 반영

## 8. 리스크

| 리스크 | 대응 |
|--------|------|
| 이미지 모더레이션 반려 | ID `0` 폴백 → 텍스트 유지. 반려 장만 재생성 |
| 아이콘 삽입으로 HUD 레이아웃 붕괴 | ImageLabel 삽입 방식(버튼 교체 금지) + Play 육안 확인 |
| ID 오기입 (기물 색 뒤바뀜) | §7 기록표와 Config 교차 대조 |

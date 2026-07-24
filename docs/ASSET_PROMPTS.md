# 01_Chess — 이미지 자산 필요 리스트 + 생성 프롬프트

**용도**: GPT-4o / Grok 이미지 생성용. 프롬프트는 영어(생성 품질↑), 사양은 표 참조.
**공통 사양**: PNG, 투명 배경(썸네일 제외), 정사각 1024×1024 생성 후 다운스케일.
**Roblox 업로드 규격**: 아이콘류 ImageLabel용 256×256 충분, 게임 아이콘 512×512, 썸네일 1920×1080.

## 스타일 앵커 (모든 프롬프트 앞에 붙일 것)

```
Stylized low-poly 3D game icon, clean vector-like rendering, soft studio lighting,
vibrant saturated colors, subtle rim light, dark navy vignette-free transparent background,
Roblox-friendly casual art style, centered composition, no text, no watermark.
```

---

## 1. 기물 아이콘 — 플레이어 (파란색 계열, 6종)

HUD 로스터/상점 구매 버튼용. 256×256.

| # | 파일명 | 프롬프트 (스타일 앵커 + 아래) |
|---|--------|------------------------------|
| 1 | `piece_pawn_blue.png` | `A single chess pawn piece, glossy sapphire blue ceramic material with glowing cyan edge accents, heroic upward angle` |
| 2 | `piece_knight_blue.png` | `A single chess knight (horse head) piece, glossy sapphire blue ceramic material with glowing cyan edge accents, proud profile view facing left` |
| 3 | `piece_bishop_blue.png` | `A single chess bishop piece, glossy sapphire blue ceramic material with glowing cyan edge accents, tall elegant silhouette` |
| 4 | `piece_rook_blue.png` | `A single chess rook (castle tower) piece, glossy sapphire blue ceramic material with glowing cyan edge accents, sturdy fortress feel` |
| 5 | `piece_queen_blue.png` | `A single chess queen piece, glossy sapphire blue ceramic material with glowing cyan edge accents, regal crown with small gem` |
| 6 | `piece_king_blue.png` | `A single chess king piece, glossy sapphire blue ceramic material with glowing cyan edge accents, majestic cross-topped crown` |

## 2. 기물 아이콘 — 적 (빨간색 계열, 6종)

적 티어 표시/도감용. 256×256. 위 6종과 동일 구도, 색만 교체.

| # | 파일명 | 프롬프트 변경점 |
|---|--------|----------------|
| 7–12 | `piece_{pawn,knight,bishop,rook,queen,king}_red.png` | 위 1–6 프롬프트에서 재질 문구를 다음으로 교체: `glossy crimson red obsidian material with glowing orange ember edge accents, slightly menacing aura` |

## 3. 보스

King 보스 전용 강조 아트. 512×512.

| # | 파일명 | 프롬프트 |
|---|--------|----------|
| 13 | `boss_king.png` | `An imposing giant chess king piece as a final boss, cracked crimson obsidian body with molten lava glowing through the cracks, dark smoke wisps, dramatic low-angle view, ominous red rim lighting` |

## 4. 강화/상점 아이콘 (Config.UPGRADES 기준)

상점 버튼용. 256×256.

| # | 파일명 | 대상 | 프롬프트 |
|---|--------|------|----------|
| 14 | `upgrade_might.png` | Might (+ATK 6%/lv) | `A stylized upward-pointing sword with a red power aura and small +arrow motif, attack power upgrade icon` |
| 15 | `upgrade_vitality.png` | Vitality (+HP 6%/lv) | `A stylized glowing green heart wrapped in a subtle shield outline, health vitality upgrade icon` |

## 5. HUD / 시스템 아이콘

256×256.

| # | 파일명 | 용도 | 프롬프트 |
|---|--------|------|----------|
| 16 | `icon_gold.png` | 골드 표시 | `A shiny gold coin with an embossed chess pawn silhouette, small sparkle highlights` |
| 17 | `icon_reroll.png` | 리롤 버튼 | `Two circular arrows forming a refresh cycle around a small chess pawn, teal color scheme` |
| 18 | `icon_restart.png` | 재시작 버튼 | `A single bold circular restart arrow with a flag motif in the center, orange color scheme` |
| 19 | `icon_transcend.png` | 초월 버튼 | `A chess pawn ascending upward surrounded by golden light rays and small star particles, ascension rebirth icon, purple-gold color scheme` |
| 20 | `icon_hp.png` | HP 수치 옆 | `A simple glossy red heart, game UI health icon` |
| 21 | `icon_atk.png` | ATK 수치 옆 | `A simple glossy crossed twin swords emblem, game UI attack icon, silver-red` |
| 22 | `icon_level.png` | 레벨/티어 표시 | `A simple glossy golden five-pointed star badge, game UI level icon` |
| 23 | `icon_crit.png` | 크리티컬 프리뷰 | `A sharp yellow-orange lightning burst impact star, critical hit icon` |

## 6. Roblox 스토어 자산 (투명 배경 아님)

| # | 파일명 | 규격 | 프롬프트 |
|---|--------|------|----------|
| 24 | `game_icon.png` | 512×512 | 스타일 앵커 + `Game icon: a heroic blue chess knight piece facing off against a menacing red king piece on a glowing 6x6 chessboard, dramatic diagonal composition, dark background with blue and red rim light, fills the entire square frame` |
| 25 | `thumbnail_main.png` | 1920×1080 | 스타일 앵커(투명 배경 문구 제거) + `Wide game thumbnail: a lone blue chess pawn standing bravely on a glowing 6x6 battle chessboard surrounded by an army of red enemy pieces, epic scale, cinematic lighting, dark arena background, empty space on the left third for logo text` |
| 26 | `thumbnail_boss.png` | 1920×1080 | 위와 동일 앵커 + `Wide game thumbnail: giant cracked lava-glowing red chess king boss towering over a small blue rook piece, David vs Goliath composition, dramatic backlight` |

---

## 미포함 (이미지 불요 판단)

- 보드 타일/하이라이트(초록·빨강) — 현재 Part Color로 처리, 이미지 불요.
- 데미지 프리뷰 숫자 — TextLabel 빌보드, 폰트로 충분.
- 사운드/이펙트 — 이미지 범위 외.

## 수령 후 처리 절차

1. PNG를 `assets/images/`(신규)로 저장, 위 파일명 준수.
2. Roblox Studio → Asset Manager 업로드 → `rbxassetid://` 확보.
3. `src/shared/Config.luau`에 `ASSET_IDS` 테이블 추가 후 HUD/BoardView에서 참조.

# Owner Live QA — 에셋/HUD (01_Chess)

Play 전:

```bash
export PATH="$HOME/.rokit/bin:/opt/homebrew/bin:$PATH"
cd …/01_Chess
npm run verify          # test + lint + audit-assets + build
asphalt sync studio     # 선택: Studio rbxasset:// 경로 (픽셀 팩만으로도 아이콘 표시 가능)
rojo build default.project.json -o build/Chess.rbxlx
```

Studio에서 `build/Chess.rbxlx` 열고 Play. Output에 `[CHESS]` 로그 확인.

## 체크리스트

### 폴백 (cloud ID 전부 0일 때)

- [ ] HUD HP / ATK / Gold / Level 옆 **아이콘 표시** (IconPixelPack EditableImage 또는 asphalt URI)
- [ ] 리롤 버튼 아이콘 표시, 클릭 동작 유지
- [ ] 목숨 strip에 기물 아이콘 (또는 이니셜 칩)
- [ ] 상점 기물/강화 버튼 아이콘 + **가격 텍스트 유지**
- [ ] 공격 타일 프리뷰에 크리 아이콘 (critChance > 0)
- [ ] Lv17 보스 진입 시 배너 2초 (아이콘 있거나 텍스트만)

### 텍스트 병행

- [ ] 아이콘이 켜져도 HP/ATK/골드 **숫자 텍스트 동일**
- [ ] 상점 버튼 이름·가격 텍스트 가독

### 회귀

- [ ] 보드 클릭 이동/공격 정상
- [ ] 리롤/재시작/초월/구매 remotes 정상
- [ ] `lune run tests/run.luau` 통과

### 스토어 (코드 외)

- [ ] Creator Hub에 game_icon / thumbnail 등록 (선택)

# 타격감(Juice) 벤치마크 → 적용 매핑

**작성** 2026-07-24 · **적용 코드** `src/client/Fx.luau` + BoardView/GameClient/HudController 배선

## 벤치마크 근거

| 기법 | 출처 | 요지 |
|------|------|------|
| Screen shake | Vlambeer "The Art of Screenshake" (GDC 2013) | 0.1–0.3초 짧은 감쇠 셰이크가 타격 무게감의 핵심 |
| Flash / floating text / sound / particles | Jonasson & Purho "Juice it or Lose it" (GDC 2012) | 기능 프로토타입에 피드백 5종만 얹어도 재미 급증 |
| Hit stop 60–80ms | [Blood Moon Interactive — Juice in Game Design](https://www.bloodmooninteractive.com/articles/juice.html) | 확정타에 짧은 정지/지연 → 결과가 "박힌다" |
| 피드백 5요소 정리 | [Where Does Game Feel Come From](https://eastondev.com/blog/en/posts/dev/20260521-game-feedback-feel/) | flash·shake·floating text·sound·particle 동시 설계 |
| 장르 레퍼런스 | Shotgun King(체스 로그라이크), Slay the Spire | 데미지 숫자 + 크리 강조 + 피격 시 화면 플래시가 표준 |

전문: [gamejuice.co.uk — Juice it or Lose it](https://gamejuice.co.uk/resources/juice-it-or-lose-it), [valdemird.com — Game feel on the web](https://valdemird.com/blog/game-feel-on-the-web/), [GameAnalytics — Squeezing more juice](https://www.gameanalytics.com/blog/squeezing-more-juice-out-of-your-game-design)

## 적용 (전부 클라 전용, 서버/엔진 무변경)

| 이벤트 (snapshot.lastResult) | 피드백 |
|------------------------------|--------|
| playerDamageDealt > 0 | 공격 타일에 `-N` 플로팅 텍스트 + 폭발음(고음 1.3x) — **피격 처리 후 0.3s 지연** |
| crit | 큰 주황 `-N CRIT!` + 폭발 사운드 + 셰이크 0.8 |
| enemyDied | 셰이크 0.5 + 빨간 파티클 버스트 (사운드 없음 — 목소리류 배제, 오너 지시) |
| playerDamageTaken > 0 | **최우선 즉시 처리(방어 먼저)** — 빨간 `-N` + 파트 펀치 + 빨간 플래시 + 데미지 비례 셰이크 + 폭발음(저음 0.8x) |
| levelCleared | 휘슬업 사운드(action_jump) |
| victory / runOver | 폭발음 / 낙하음(action_falling) + 암적색 플래시 |
| HP/Gold 변화 | HUD 라벨 색·크기 펄스 (`Fx.pulseText`) |
| 말 이동 | 순간이동 → 0.14s Quad 트윈 슬라이드 |
| 버튼 | hover 확대 + press 축소 + click 사운드 (상점은 press 전용 — 리스트 리플로우 방지) |

사운드 전부 엔진 내장 `rbxasset://sounds/*` (현행 Studio 실존 11개 파일만 사용 — 클래식 swordslash 등은 삭제됨) — 업로드·모더레이션 불필요, 오프라인 로드.
추가: 업그레이드 구매 성공(action_get_up) / 기물 구매 성공(action_jump_land) 사운드 — profile.upgrades 합계·roster 증가 감지.

중복 발화 방지: `snapshot.roundsPlayed` 라운드당 1회.

## 미적용 (다음 후보)

- 파티클 (죽음 버스트, 크리 스파크) — ParticleEmitter, 소규모
- 진짜 hit stop (전투 애니메이션 프레임 정지) — 실시간 애니메이션 도입 후에나 의미
- 커스텀 사운드 (rbxassetid 업로드 필요 — 에셋 PRD 파이프라인 재사용)

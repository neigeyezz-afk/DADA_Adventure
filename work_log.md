# DADA Adventure — 전체 개발 및 수정 작업 로그 (Work Log)

**생성 일시**: 2026년 7월 31일
**프로젝트**: DADA Adventure 260709
**상태**: 완료 (All Systems Verified)

---

## 1. 🎨 Godot 순수 픽셀 그래픽 전환 (Godot Native Pixel Art Engine)
- **원칙 준수**: 외부 이미지 자르기 방식 대신 Godot의 `ColorRect` 조합 기반 절차적 픽셀 아트 엔진 구현
- **구글 'G' 픽셀 아이콘 (`title_screen.gd`)**:
  - 손상된 외부 이미지(`google sign.png`) 로딩 에러(`ERR_FILE_CORRUPT`)를 완전히 제거하고 4색(Red, Yellow, Green, Blue) 절차적 픽셀 구글 로고 아이콘 자동 생성 적용
- **타일셋 및 배경 요소**:
  - **꽃(Flower)**: Sky Blue, Daisy, Golden Cluster 3종 절차적 픽셀 꽃잎 및 미풍 흔들림 애니메이션
  - **풀숲(Bush)**: 5종 다양한 픽셀 풀숲 (빨간 열매 풀숲 포함), `custom_scale` 및 레이어링(`z_index = 15`)
  - **나무(Tree)**: Oak Tree(둥근 차양) & Pine Tree(3단 피라미드) 픽셀 아트
  - **구름(Cloud)**: 하늘을 유영하는 수평 드래프트 픽셀 구름
  - **지층 데코(`pixel_tile_decorator.gd`)**: 표토, 암석 자갈, 상단 풀 테두리, 수풀 드레이프

---

## 2. 🪜 사다리 & 덩굴(Vine) 등반 물리 매커니즘
- **덩굴 픽셀 그래픽 지원 (`ladder.gd`)**:
  - 원목 사다리(Wooden) 및 푸릇푸릇한 픽셀 덩굴(Vine) 모드 구현
  - 첫 번째 사다리 (`Ladder1`)를 **덩굴 사다리 (`is_vine = true`)**로 배치
- **지면 연장 및 스무스 등반**:
  - `Ladder1`, `Ladder5` 사다리를 지면까지 연장 (`position.y = 0`, `height = 347.0`)
  - 등반 중 발판 천장 충돌 해제(`collision_mask = 0`) 및 최상단 도달 시 발판 상단 표면 착지(`top_y - 20.0`, `collision_mask = 1`)
  - `_physics_process()` 내 지속 영역 검사로 지면에서 즉시 탑승 가능

---

## 3. 🕹️ 조작법 & UI/UX 개편
- **플레이어 시작 위치**:
  - 캐릭터 좌우 폭(38px)의 2배 거리인 **좌측 끝 76px (`Vector2(76, -90)`) 지점을 시작점**으로 배치
- **신규 단축키 시스템**:
  - **[P] 키 (Pause)**: 게임 일시정지, 어두운 딤 화면 + 중앙 픽셀 일시정지 아이콘(`||`) 표시
  - **[R] 키 (Recipe Book)**: 레시피북 열기/닫기 (우상단 HUD 버튼의 'R' 자 노란색 강조)
  - **[Q] 키 (Inventory)**: 인벤토리 및 요리/상점 패널 열기/닫기
- **레트로 아케이드 조이스틱 오브제 (`tutorial_sign.gd`)**:
  - 기존 나무 표지판을 **레트로 게임기 조이스틱 아케이드 캐비닛** 픽셀 아트(레드 볼 레버, 버튼, 스크린 마키)로 변경
  - 조이스틱 상단을 가리던 풀숲 위치 조정
  - 안내 문구 길이에 맞춘 팝업창 폭 자동 맞춤(Auto-fit) 및 R, P, Q 단축키 설명 통합
- **타이머 디자인**:
  - 타이머 뒷배경 검정 패널 제거
  - 타이머 숫자 크기 **2배 확장 (font_size = 60)** 및 선명한 픽셀 아웃라인

---

## 4. ⚠️ 버그 수정 및 안정성 보완
- **구덩이 추락 리턴 에러 해결**:
  - `fall_into_pit()` 호출 시 물리 충돌 쿼리 플러시 중 씬 전환 에러 방지를 위한 `call_deferred("_deferred_return_to_title")` 적용 (사망 음향 + floating text 출력 후 타이틀 화면으로 안전 복귀)
- **GDScript 타입 추론 파싱 에러 수정**:
  - `hud.gd` 74행의 `event.keycode` 타입 추론 에러를 `var k_event := event as InputEventKey`, `var key: Key = k_event.keycode` 명시적 캐스팅으로 해결
- **점프 구간 발판 천장 개방**:
  - `Platform3`를 `Platform3A`와 `Platform3B`로 분할하여 구덩이 점프 시 머리가 걸리지 않도록 260px 천장 개방

---
*DADA Adventure Project Log Update Complete.*

# 개발 워크플로우

기능 개발/수정/버그 수정을 TDD 방식으로 수행한다.

**여러 세션에서 동시에 다른 기능을 개발할 수 있다.** 각 기능은 `.ai-company/dev/{slug}/`에 독립적으로 상태를 관리한다.

인자: $ARGUMENTS
- 기능 설명: `게시판 CRUD API 추가`
- Phase 강제 재실행: `--respec` (Phase 1), `--retest` (Phase 2)
- 특정 Phase부터 시작: `--from 3` (Phase 3부터)
- 진행 목록: `--list`

---

## 상태 머신

```
spec → red → green → reviewed → merged
                  → blocked → (사람 판단) → spec 또는 green
```

상태는 `.ai-company/dev/{slug}/status.json`에 기록:
```json
{
  "slug": "board-crud",
  "status": "red",
  "feature": "게시판 CRUD API 추가",
  "branch": "feature/board-crud",
  "specFile": ".ai-company/dev/board-crud/spec.md",
  "testFiles": [],
  "changedFiles": [],
  "startedAt": "ISO 날짜",
  "updatedAt": "ISO 날짜"
}
```

---

## 기능 식별 (slug)

### $ARGUMENTS에 기능명이 있을 때
1. `.ai-company/dev/` 하위 디렉토리를 스캔하여 `status.json`의 `feature`와 매칭
2. **매칭됨**: 해당 slug의 status에 따라 Phase 진입
3. **매칭 안 됨**: 새 기능으로 판단 → slug 생성 → Phase 1

### $ARGUMENTS가 없을 때
1. `.ai-company/dev/` 하위 디렉토리 스캔
2. 진행 중 1개 → 자동 진입 / 여러 개 → 선택 요청 / 없음 → 입력 요청

### slug 생성: 기능명에서 핵심 단어 추출 → kebab-case. 충돌 시 숫자 접미사.

---

## Phase 라우팅

status.json의 status에 따라:
- 없음 또는 `--respec` → **Phase 1**
- `spec` 또는 `--retest` → **Phase 2**
- `red` → **Phase 3**
- `green` → **Phase 4**
- `reviewed` → **Phase 5**
- `blocked` → 사람에게 상황 안내

---

## Phase 1: 구현 명세 [메인 세션, 대화형]

개발자와 대화하여 `.ai-company/dev/{slug}/spec.md` 작성:

**1단계: 변경 유형 파악** — 신규 기능 / 기존 기능 수정 / 버그 수정

**2단계: 유형별 필수 질문**

신규 기능:
- 어떤 API 엔드포인트가 필요한가?
- 새 데이터 모델/테이블이 필요한가?
- 인증/인가가 필요한가?
- 다른 서비스에 영향을 주는가?

기존 기능 수정:
- 어떤 엔드포인트를 수정하는가?
- 기존 클라이언트에 breaking change가 있는가?
- DB 스키마 변경이 필요한가?

버그 수정:
- 현재 동작 vs 기대 동작은?
- 재현 조건은?
- 영향 범위는?

**3단계: 엣지케이스** — 동시성, 대용량 처리, 실패 시 롤백

**4단계: 수용 기준 합의** — 테스트 가능한 문장으로 작성

산출물: `spec.md`, `status.json` (status: `spec`)
기능 브랜치 생성: `feature/{slug}` (사람 확인 후)

### 여기서 멈춤 — spec 승인 요청.

---

## Phase 2: 테스트 작성 [서브에이전트: spec-test-writer]

기능 브랜치 확인 후 **`spec-test-writer`** 에이전트 실행.

프롬프트 포함: spec.md 경로, PROJECT_CONTEXT.md 경로, docker-compose.test.yml 경로, integration/support/ 존재 여부.

결과: **RED** → status `red` / **ERROR** → 보고 후 멈춤.

### 여기서 멈춤 — 테스트 의도 검수 요청.

---

## Phase 3: 구현 [서브에이전트: impact-analyzer → implementer]

### 영향 분석 (구현 전)
**`impact-analyzer`** 에이전트로 파일 충돌/크로스 영향 사전 확인.
- **SAFE**: 진행 / **CAUTION**: 안내 후 진행 / **CONFLICT**: 사람에게 보고

### 구현
**`implementer`** 에이전트 실행.

프롬프트 포함: spec.md, 테스트 파일, PROJECT_CONTEXT.md, docker-compose.test.yml 경로.

결과: **GREEN** → status `green`, Phase 4 자동 진행 / **BLOCKED** → status `blocked`, 멈춤.

---

## Phase 4: 코드 리뷰 [서브에이전트: code-reviewer]

**`code-reviewer`** 에이전트 실행.

프롬프트 포함: spec.md, changedFiles, 테스트 파일, PROJECT_CONTEXT.md 경로.

### 결과 처리
- **PASS**: 멈춤으로 진행
- **NEEDS_WORK**:
  - **minor**: 메인 세션이 직접 반영
  - **major**: implementer 재호출 (리뷰 지적사항 포함)
  - 반영 후 code-reviewer 재실행 (최대 2차까지)
- 2차에도 NEEDS_WORK → 남은 지적사항 포함하여 멈춤

### 여기서 멈춤 — status `reviewed`. 사람 최종 검수 요청.

---

## Phase 5: MR + 알림 [메인 세션]

1. 전체 테스트 최종 실행
2. git add + commit (spec 기반 메시지)
3. push feature/{slug}
4. `gh pr create` (수용 기준 + 변경 파일 + 테스트 커버리지 + 리뷰 요약)
5. Slack 알림 (`.ai-company/config.json`에 webhook 설정 시)

status → `merged`.

---

## 마이그레이션 (v2 → v3)

기존 `.dev/` 디렉토리 감지 시 `.ai-company/dev/`로 이동 안내.

---

## tip 출력 규칙

각 "여기서 멈춤" 시점에 `agents/tip-advisor.md` 참조하여 상황에 맞는 tip 1개 출력. 세션 내 중복 안내 금지.

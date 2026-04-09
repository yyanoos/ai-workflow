# 개발 워크플로우

기능 개발/수정/버그 수정을 TDD 방식으로 수행한다.
테스트를 먼저 작성하고, 구현하고, 리뷰하고, MR을 만든다.

**여러 세션에서 동시에 다른 기능을 개발할 수 있다.** 각 기능은 `.dev/{slug}/`에 독립적으로 상태를 관리한다.

인자: $ARGUMENTS
- 기능 설명: `게시판 CRUD API 추가`
- Phase 강제 재실행: `--respec` (Phase 1), `--retest` (Phase 2)
- 특정 Phase부터 시작: `--from 3` (Phase 3부터)

---

## 상태 머신

```
spec → red → green → reviewed → merged
                  → blocked → (사람 판단) → spec 또는 green
```

| status | 의미 |
|--------|------|
| `spec` | 구현 명세 작성 완료, 테스트 대기 |
| `red` | 테스트 작성 완료 (실패 상태), 구현 대기 |
| `green` | 전체 테스트 통과, 리뷰 대기 |
| `reviewed` | 리뷰 통과, 사람 최종 검수 대기 |
| `blocked` | 구현 불가, 사람 판단 필요 |
| `merged` | MR 생성 완료 |

상태는 `.dev/{slug}/status.json`에 기록한다:
```json
{
  "slug": "board-crud",
  "status": "red",
  "feature": "게시판 CRUD API 추가",
  "branch": "feature/board-crud",
  "specFile": ".dev/board-crud/spec.md",
  "testFiles": ["src/test/.../integration/BoardControllerIT.java"],
  "changedFiles": [],
  "startedAt": "ISO 날짜",
  "updatedAt": "ISO 날짜"
}
```

---

## 기능 식별 (slug)

`/dev` 실행 시 대상 기능을 결정하는 로직:

### $ARGUMENTS에 기능명이 있을 때
1. `.dev/` 하위 디렉토리를 스캔하여 `status.json`의 `feature`와 매칭
2. **매칭됨**: 해당 slug의 status에 따라 Phase 진입
3. **매칭 안 됨**: 새 기능으로 판단 → slug 생성 → Phase 1

### $ARGUMENTS가 없을 때 (또는 플래그만 있을 때)
1. `.dev/` 하위 디렉토리 스캔
2. 진행 중인 기능(`merged`가 아닌 것)이 **1개**: 해당 기능으로 자동 진입
3. 진행 중인 기능이 **여러 개**: 목록을 보여주고 선택 요청
4. 진행 중인 기능이 **없음**: "기능 설명을 입력해주세요" 안내

### slug 생성 규칙
- 기능명에서 한국어/영어 핵심 단어 추출 → kebab-case
- 예: "게시판 CRUD API 추가" → `board-crud`
- 예: "로그인 버그 수정" → `login-bugfix`
- 충돌 시 숫자 접미사: `board-crud-2`

---

## 실행 흐름

`.dev/{slug}/status.json`의 status에 따라 Phase 진입:
- `spec` → Phase 2
- `red` → Phase 3
- `green` → Phase 4
- `reviewed` → Phase 5
- `blocked` → 사람에게 상황 안내, Phase 1 또는 3 재시작 여부 확인

---

## Phase 1: 구현 명세 [메인 세션, 대화형]

해당 slug의 `spec.md`가 없거나 `--respec` 플래그가 있으면 실행한다.

### 실행

개발자와 대화하여 구현 명세를 작성한다. 다음 순서로 질문한다:

**1단계: 변경 유형 파악**
- 신규 기능 / 기존 기능 수정 / 버그 수정 중 무엇인지

**2단계: 유형별 질문**

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

**3단계: 엣지케이스 논의**
- 동시성 문제가 있을 수 있는가?
- 대용량 데이터 처리가 필요한가?
- 실패 시 롤백 전략은?

**4단계: 수용 기준 합의**
- 이 기능이 "완료"되려면 어떤 조건을 만족해야 하는가?
- 각 조건을 테스트 가능한 문장으로 작성

### 산출물

`.dev/{slug}/spec.md` 생성:
```markdown
# 구현 명세: {기능 이름}

## 변경 유형
신규 기능 / 기존 기능 수정 / 버그 수정

## 설명
(1-3줄)

## 수용 기준
- [ ] POST /api/boards 호출 시 게시판이 생성된다
- [ ] 제목이 빈 값이면 400을 반환한다
- [ ] 인증 없이 호출하면 401을 반환한다

## 영향 범위
- 변경 서비스: member
- 변경 파일 (예상): BoardController, BoardService, Board 엔티티
- DB 스키마 변경: board 테이블 추가 (컬럼: id, title, content, created_at)

## 주의사항
(대화 중 나온 엣지케이스, 제약사항)
```

`.dev/{slug}/status.json` 생성 (status: `spec`)

### 기능 브랜치 생성

spec 승인 후 기능 브랜치를 생성한다:
- 브랜치명: `feature/{slug}` (예: `feature/board-crud`)
- 사람에게 확인: "feature/{slug} 브랜치를 생성할까요?"
- 승인 시 `git checkout -b feature/{slug}` 실행
- status.json에 `branch` 필드 기록

### 여기서 멈춤
사람에게 spec.md를 보여주고 승인을 요청한다. 수용 기준이 맞는지 확인하라고 안내.

---

## Phase 2: 테스트 작성 [서브에이전트: spec-test-writer]

status가 `spec`이거나 `--retest` 플래그가 있으면 실행한다.

### 사전 확인
- 기능 브랜치에 있는지 확인. 없으면 `git checkout feature/{slug}` 실행.

### 실행

**`spec-test-writer` 에이전트**를 실행한다.
(에이전트 정의: `agents/spec-test-writer.md`)

에이전트 프롬프트에 포함할 내용:
- `.dev/{slug}/spec.md` 절대경로
- PROJECT_CONTEXT.md 절대경로
- docker-compose.test.yml 절대경로
- 기존 integration/support/ 존재 여부

### 결과 처리 (메인 세션)
- **RED**: 정상. status → `red`, testFiles 업데이트
- **ERROR**: 에러 내용을 사람에게 보고 후 멈춤

### 여기서 멈춤

RED 상태인 테스트를 사람에게 보여주고 검수를 요청한다.

```
테스트 작성 완료 (RED):
  - 기능: 게시판 CRUD API 추가 [board-crud]
  - 브랜치: feature/board-crud
  - 테스트 파일: src/test/.../integration/BoardControllerIT.java
  - 테스트 케이스: 5개 (전부 의도된 실패)
  - 마이그레이션: src/main/resources/db/migration/V3__add_board_table.sql (생성됨)

테스트 의도가 맞는지 확인 후 다시 /dev 를 실행하면 구현을 시작합니다.
```

---

## Phase 3: 구현 [서브에이전트: implementer]

status가 `red`이면 실행한다.

### 사전 확인
- 기능 브랜치에 있는지 확인. 없으면 `git checkout feature/{slug}` 실행.

### 실행

**`implementer` 에이전트**를 실행한다.
(에이전트 정의: `agents/implementer.md`)

에이전트가 프로덕션 코드를 작성하고, 전체 테스트(새 것 + 기존 것)를 통과시킨다.

에이전트 프롬프트에 포함할 내용:
- `.dev/{slug}/spec.md` 절대경로
- 테스트 파일 절대경로
- PROJECT_CONTEXT.md 절대경로
- docker-compose.test.yml 절대경로

### 결과 처리 (메인 세션)
- **GREEN**: status → `green`, changedFiles 업데이트. Phase 4로 자동 진행.
- **BLOCKED**: status → `blocked`, 중단 사유를 사람에게 보고 후 멈춤.
  사람이 판단: spec 수정(Phase 1로) 또는 직접 해결 후 재시작.

---

## Phase 4: 코드 리뷰 [서브에이전트: code-reviewer]

status가 `green`이면 자동 실행한다.

### 실행

**`code-reviewer` 에이전트**를 실행한다.
(에이전트 정의: `agents/code-reviewer.md`)

에이전트 프롬프트에 포함할 내용:
- `.dev/{slug}/spec.md` 절대경로
- 변경된 파일 경로 목록 (status.json의 changedFiles)
- 테스트 파일 절대경로
- PROJECT_CONTEXT.md 절대경로

### 1차 리뷰 결과 처리
- **PASS**: 여기서 멈춤으로 진행
- **NEEDS_WORK**:
  - **minor** 지적: 메인 세션이 직접 반영
  - **major** 지적: implementer 서브에이전트 재호출 (프롬프트에 spec.md + 리뷰 지적사항 + 변경 파일 경로 포함)
  - 반영 후 전체 테스트 재실행하여 통과 확인
  - code-reviewer 재실행 (2차 리뷰)

### 2차 리뷰 결과 처리
- **PASS**: 여기서 멈춤으로 진행
- **NEEDS_WORK**: 남은 지적사항을 보고에 포함하고 여기서 멈춤 (사람이 판단)

### 여기서 멈춤

status → `reviewed`.

```
리뷰 완료: 게시판 CRUD API 추가 [board-crud]
  - 브랜치: feature/board-crud
  - 변경 파일: 5개
  - 테스트: 5/5 통과 (전체 테스트 포함)
  - 리뷰: PASS (또는 NEEDS_WORK → 3건 반영 → 2차 PASS)
  - 미반영 지적사항: (있으면 표시)

검수 후 다시 /dev 를 실행하면 MR을 생성합니다.
```

---

## Phase 5: MR + 알림 [메인 세션]

status가 `reviewed`이면 실행한다.

### 사전 확인
1. 기능 브랜치에 있는지 확인
2. 전체 테스트 최종 실행 — 통과 확인
3. status가 `reviewed`인지 확인

### 실행

1. **커밋**: 변경 파일을 git add + commit
   - 커밋 메시지: spec.md 기반으로 생성
2. **푸시**: 기능 브랜치(`feature/{slug}`)를 원격에 push
3. **MR 생성**: `gh pr create` 또는 해당 플랫폼 CLI
   - 제목: spec.md의 기능 이름
   - 본문: 수용 기준 + 변경 파일 목록 + 테스트 커버리지 + 리뷰 요약
4. **Slack 알림** (설정 있으면): MR URL 포함

### Slack 설정

프로젝트의 CLAUDE.md 또는 `.dev/config.json`에:
```json
{
  "slack": {
    "webhookUrl": "https://hooks.slack.com/services/...",
    "channel": "#dev-pr"
  }
}
```
설정이 없으면 Slack 알림은 스킵한다.

### 완료

status → `merged`.

```
MR 생성 완료: 게시판 CRUD API 추가 [board-crud]
  - PR: https://github.com/org/repo/pull/123
  - 브랜치: feature/board-crud
  - Slack 알림: 전송됨 (#dev-pr)
```

`.dev/{slug}/` 디렉토리는 유지한다 (이력 참조용).

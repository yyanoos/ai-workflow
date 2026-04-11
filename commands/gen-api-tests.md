# API 통합 테스트 자동 생성

기존 프로젝트에 테스트 커버리지를 구축한다. 실행할 때마다 미완료 엔드포인트 1개를 처리하고 멈추므로, 사람이 검수한 뒤 다시 실행하면 된다.

인자: $ARGUMENTS
- 없으면: 자동으로 다음 미완료 엔드포인트 처리
- 엔드포인트 지정: `POST /api/auth/login`
- Phase 강제 재실행: `--reanalyze` (Phase 0), `--rescan` (Phase 1)
- 실패 재시도: `--retry-failed` (failed 상태인 엔드포인트를 pending으로 리셋)

**⚠ 이 워크플로우는 단일 세션에서 실행한다.** endpoints.json을 공유 상태로 사용하므로, 여러 세션에서 동시에 실행하면 status가 꼬일 수 있다. 여러 기능을 병렬 개발할 때는 `/dev`를 사용할 것.

---

## 상태 머신

```
pending → (Phase 2: 생성+실행) → (Phase 3: AI리뷰) → review → (사람 승인) → done
                              → failed → (--retry-failed) → pending
```

| status | 의미 |
|--------|------|
| `pending` | 테스트 미생성 |
| `review` | 테스트 통과 + AI 리뷰 완료, 개발자 최종 검수 대기 |
| `done` | 개발자 승인 완료 |
| `failed` | 3회 실패, 수동 개입 필요 |

---

## 실행 흐름

아래 Phase를 순서대로 확인하며, 해당 Phase의 산출물이 없으면 그 Phase를 실행하고 **멈춘다**.
이미 산출물이 있으면 다음 Phase로 넘어간다.

### Phase 진입 우선순위

Phase 0, 1은 산출물 유무로 판단. Phase 2 이후는 endpoints.json의 status로 판단하며, **우선순위**:
1. `"review"` 상태가 있으면 → Phase 4 (사람 승인 처리)
2. `"pending"` 상태가 있으면 → Phase 2 (새 테스트 생성)
3. 전부 `"done"` 이면 → 완료 안내

---

## Phase 0: 프로젝트 분석 (PROJECT_CONTEXT.md 없을 때)

프로젝트 루트에 `PROJECT_CONTEXT.md`가 없거나, `--reanalyze` 플래그가 있으면 실행한다.
`--reanalyze` 시 기존 PROJECT_CONTEXT.md와 [AI-CONTEXT] 주석을 덮어쓴다.

### 실행

**`project-analyzer` 에이전트**를 실행한다.
(에이전트 정의: `agents/project-analyzer.md`)

에이전트가 프로젝트 전체를 분석하여:
- `PROJECT_CONTEXT.md` 생성 (에이전트용 프로젝트 인덱스 + 도메인 지식. 줄 수 제한 없음)
- 각 컨트롤러 메서드에 `[AI-CONTEXT]` 주석 추가 (내부 흐름, 크로스 서비스 영향, 사이드이펙트, 주의사항)

### 산출물
- 프로젝트 루트에 `PROJECT_CONTEXT.md`
- 컨트롤러/라우트 파일에 `[AI-CONTEXT]` 주석
- 테스트 인프라 부트스트랩 (없을 때만 생성):
  - `docker-compose.test.yml` (테스트용 인프라)
  - 테스트 프로필 설정 (`application-integration.yml` 등)
  - 테스트 의존성 추가 (`build.gradle` 등)
  - DB 스키마 초기화 설정
- CLAUDE.md에 아래 내용이 없으면 추가:
  ```
  ## 프로젝트 컨텍스트
  매 세션 시작 시 `PROJECT_CONTEXT.md`를 반드시 읽을 것.
  ```

### 여기서 멈춤
사람에게 **의도 검수만** 요청한다:
- PROJECT_CONTEXT.md: 인덱스가 정확한지, 도메인 지식이 맞는지
- [AI-CONTEXT] 주석: 내부 흐름과 크로스 서비스 영향이 정확한지

테스트 인프라(docker-compose, 프로필, 의존성, DB 스키마)는 에이전트가 실제로 기동+연결 테스트까지 완료한 상태이므로, 사람이 동작 검증할 필요 없음.

---

## Phase 1: 엔드포인트 스캔 (endpoints.json 없을 때)

`.ai-company/qa/coverage/endpoints.json`이 없거나, `--rescan` 플래그가 있으면 실행한다.
`--rescan` 시 기존 endpoints.json을 덮어쓰되, `"done"`, `"review"`, `"failed"` 상태는 유지한다.

### 마이그레이션 (v2 → v3)

기존 `.test-coverage/` 디렉토리가 존재하면 자동 감지하여 안내:
```
기존 .test-coverage/ 디렉토리를 감지했습니다.
.ai-company/qa/coverage/ 로 이동하면 새 프레임워크와 통합됩니다.

이동하시겠습니까? (이동 / 나중에)
```
- "이동" 선택 시: `.test-coverage/*` → `.ai-company/qa/coverage/*` 로 복사
- "나중에" 선택 시: 기존 `.test-coverage/`에서 그대로 동작 (하위호환)

### 실행

**`endpoint-scanner` 에이전트**를 실행한다.
(에이전트 정의: `agents/endpoint-scanner.md`)

에이전트 프롬프트에 포함할 내용:
- 프로젝트 루트 절대경로
- `--rescan` 시: 기존 endpoints.json의 내용을 JSON 텍스트로 포함 (done/review 상태 보존용)

`.ai-company/qa/coverage/`는 git에 커밋한다 (팀원과 진행 상태 공유)

### 산출물
- `.ai-company/qa/coverage/endpoints.json`
- 스캔 결과 요약 출력 (총 엔드포인트 수, 컨트롤러별 수)

### 여기서 멈춤
사람에게 스캔 결과 검수를 요청한다. 빠진 엔드포인트가 없는지 확인하라고 안내.

---

## Phase 2: 테스트 생성 + 실행

endpoints.json과 PROJECT_CONTEXT.md가 모두 있으면 이 Phase부터 실행.

### 사전 처리 (메인 세션)
- `--retry-failed` 플래그가 있으면: 모든 `"failed"` 상태를 `"pending"`으로 리셋한 뒤 진행

### 대상 선택 (메인 세션)
- `$ARGUMENTS`에 엔드포인트가 지정되면: 매칭되는 엔드포인트 선택 (status 무관)
- 없으면: `"status": "pending"` 인 첫 번째 엔드포인트
- 전부 `"done"` 이면: "모든 엔드포인트 테스트 완료!" 출력 후 종료

선택된 엔드포인트를 출력:
```
대상: POST /api/auth/login (AuthController)
```

### 실행

**`test-writer` 에이전트**를 실행한다.
(에이전트 정의: `agents/test-writer.md`)

에이전트가 테스트 작성 → 실행 → 실패 시 수정(최대 3회)까지 모두 수행한다.

에이전트 프롬프트에 포함할 내용:
- 대상 엔드포인트의 endpoints.json 항목 (JSON 텍스트로)
- 컨트롤러 파일 절대경로
- 서비스 파일 절대경로 (있으면)
- PROJECT_CONTEXT.md 절대경로
- docker-compose.test.yml 절대경로
- 첫 번째 엔드포인트 여부 (integration/ 디렉토리 존재 유무)

### 결과 처리 (메인 세션)
- **PASS**: Phase 3으로 진행
- **FAIL**: endpoints.json 해당 엔드포인트 status → `"failed"`, 에러 메시지와 함께 사람에게 보고 후 멈춤

---

## Phase 3: 서브에이전트 리뷰

Phase 2에서 테스트가 통과한 직후 자동 실행.

**`test-reviewer` 에이전트**를 실행한다.
(에이전트 정의: `agents/test-reviewer.md`)

에이전트 프롬프트에 포함할 내용:
- 테스트 파일 절대경로
- 컨트롤러 파일 절대경로
- 서비스 파일 절대경로 (있으면)
- PROJECT_CONTEXT.md 절대경로

### 1차 리뷰 결과 처리
- **PASS**: 여기서 멈춤으로 진행
- **NEEDS_WORK**:
  1. 메인 세션이 test-reviewer의 제안사항을 테스트 파일에 직접 반영 (test-reviewer는 읽기 전용)
  2. 수정된 테스트를 재실행하여 통과 확인
  3. test-reviewer를 한 번 더 실행 (2차 리뷰)

### 2차 리뷰 결과 처리
- **PASS**: 여기서 멈춤으로 진행
- **NEEDS_WORK**: 남은 지적사항을 보고에 포함하고, 여기서 멈춤으로 진행 (사람이 판단)

### 여기서 멈춤

테스트 통과 + AI 리뷰 완료된 테스트를 사람에게 보여주고 최종 검수를 요청한다.
endpoints.json 해당 엔드포인트 status → `"review"`.

```
테스트 생성 완료: POST /api/auth/login (AuthController)
  - 테스트 파일: src/test/.../integration/AuthControllerIT.java
  - 테스트 케이스: 4개 (성공1, 실패1, 인증1, 유효성1)
  - 실행: 4/4 통과 (1회차)
  - AI 리뷰: PASS (또는 NEEDS_WORK → 2건 반영 → 2차 리뷰 PASS)
  - 미반영 지적사항: (있으면 표시)

검수 후 다시 /gen-api-tests 를 실행하면 승인 처리됩니다.
진행 현황: 0/45 완료 (0.0%)
```

---

## Phase 4: 승인 (status가 "review"인 엔드포인트가 있을 때)

`"review"` 상태인 엔드포인트를 `"done"`으로 변경하고 다음 pending 엔드포인트의 Phase 2를 시작한다.

```
✓ 승인: POST /api/auth/login → done

진행 현황: 1/45 완료 (2.2%)
다음 대상: GET /api/members (MemberController)
```

이어서 Phase 2가 자동으로 실행된다 (pending이 남아있으면).

모든 엔드포인트가 완료되면: "모든 API 테스트 커버리지 구축 완료!" 안내.

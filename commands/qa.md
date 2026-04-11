# QA팀

테스트 전략 수립, 테스트 커버리지 구축, 테스트 리뷰를 담당한다.

인자: $ARGUMENTS
- 없으면: 현재 상태에 따라 자동 진행
- `test-coverage`: 엔드포인트 1개씩 통합 테스트 구축 (구 /gen-api-tests)
- `test-coverage POST /api/auth/login`: 특정 엔드포인트 지정
- `strategy`: 테스트 전략 수립
- `--reanalyze`: Phase 0 강제 재실행
- `--rescan`: Phase 1 강제 재실행
- `--retry-failed`: 실패한 엔드포인트를 pending으로 리셋

**단일 세션에서 실행한다.** endpoints.json을 공유 상태로 사용하므로, 여러 세션에서 동시에 실행하면 status가 꼬일 수 있다.

---

## test-coverage (기본 모드)

기존 프로젝트에 테스트 커버리지를 구축한다. 실행할 때마다 미완료 엔드포인트 1개를 처리하고 멈추므로, 사람이 검수한 뒤 다시 실행하면 된다.

### 상태 머신

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

### 상태 파일 위치

- `.ai-company/qa/coverage/endpoints.json` (기존 `.test-coverage/endpoints.json`에서 이동)
- PROJECT_CONTEXT.md는 프로젝트 루트 유지

### 마이그레이션 (v2 → v3)

기존 `.test-coverage/` 디렉토리가 존재하면 자동 감지하여 안내:
```
기존 .test-coverage/ 디렉토리를 감지했습니다.
.ai-company/qa/coverage/ 로 이동하면 새 프레임워크와 통합됩니다.

이동하시겠습니까? (이동 / 나중에)
```
- "이동" 선택 시: `.test-coverage/*` → `.ai-company/qa/coverage/*` 로 복사
- "나중에" 선택 시: 기존 `.test-coverage/`에서 그대로 동작 (하위호환)

### Phase 진입 우선순위

Phase 0, 1은 산출물 유무로 판단. Phase 2 이후는 endpoints.json의 status로 판단하며, **우선순위**:
1. `"review"` 상태가 있으면 → Phase 4 (사람 승인 처리)
2. `"pending"` 상태가 있으면 → Phase 2 (새 테스트 생성)
3. 전부 `"done"` 이면 → 완료 안내

---

### Phase 0: 프로젝트 분석

PROJECT_CONTEXT.md가 없거나 `--reanalyze` 플래그가 있으면 실행한다.

**`project-analyzer` 에이전트**를 실행한다.

산출물:
- PROJECT_CONTEXT.md
- [AI-CONTEXT] 주석
- 테스트 인프라 부트스트랩

여기서 멈춤 — 의도 검수.

---

### Phase 1: 엔드포인트 스캔

`.ai-company/qa/coverage/endpoints.json`이 없거나 `--rescan` 플래그가 있으면 실행한다.

**`endpoint-scanner` 에이전트**를 실행한다.

산출물:
- `.ai-company/qa/coverage/endpoints.json`

여기서 멈춤 — 빠진 엔드포인트 검수.

---

### Phase 2: 테스트 생성 + 실행

**`test-writer` 에이전트**를 실행한다.

결과 처리:
- **PASS**: Phase 3으로 자동 진행
- **FAIL**: status → `"failed"`, 보고 후 멈춤

---

### Phase 3: AI 리뷰

**`test-reviewer` 에이전트**를 실행한다.

### 1차 리뷰 결과 처리
- **PASS**: 여기서 멈춤으로 진행
- **NEEDS_WORK**:
  - **major** 지적: 반드시 반영 (보안/인증/데이터 무결성 관련)
  - **minor** 지적: 반영 권장, 사람 판단으로 스킵 가능
  - 반영 후 재실행 + 2차 리뷰 (1회 고정)

2차에도 NEEDS_WORK → 남은 지적사항 포함하여 멈춤.

여기서 멈춤 — status → `"review"`.

---

### Phase 4: 승인

`"review"` → `"done"` 변경 후 다음 pending으로 자동 진행.

---

## strategy 모드

`/qa strategy` 실행 시:
- 프로젝트의 테스트 현황 분석
- 어떤 종류의 테스트가 필요한지 (단위/통합/E2E)
- 우선순위 제안
- `.ai-company/qa/test-strategy.md` 생성

---

## project.json 연동

QA 작업 시 `.ai-company/project.json`의 activeWork에 기록:
```json
{
  "department": "qa",
  "task": "test-coverage",
  "status": "in-progress",
  "progress": "12/45 완료 (26.7%)"
}
```

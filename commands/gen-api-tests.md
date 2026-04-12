# API 통합 테스트 자동 생성

> **이 커맨드는 `/qa test-coverage`로 통합되었습니다.**
> 기존 사용자를 위해 하위호환을 유지하며, 내부적으로 `/qa` 와 동일한 흐름을 따릅니다.

기존 프로젝트에 테스트 커버리지를 구축한다. 실행할 때마다 미완료 엔드포인트 1개를 처리하고 멈춘다.

인자: $ARGUMENTS
- 없으면: 자동으로 다음 미완료 엔드포인트 처리
- 엔드포인트 지정: `POST /api/auth/login`
- `--reanalyze`: Phase 0 강제 재실행
- `--rescan`: Phase 1 강제 재실행
- `--retry-failed`: failed → pending 리셋

**단일 세션에서 실행할 것.** endpoints.json을 공유 상태로 사용.

---

## 실행

**이 커맨드는 `/qa test-coverage`와 동일하게 동작한다.**
`commands/qa.md`를 읽고, test-coverage 모드의 절차를 그대로 따라라.
$ARGUMENTS는 그대로 전달한다.

### 상태 파일 위치

- 신규: `.ai-company/qa/coverage/endpoints.json`
- 레거시: `.test-coverage/endpoints.json` (감지 시 이동 안내)

### Phase 요약

| Phase | 내용 | 에이전트 |
|-------|------|----------|
| 0 | 프로젝트 분석 (PROJECT_CONTEXT.md 없을 때) | project-analyzer |
| 1 | 엔드포인트 스캔 (endpoints.json 없을 때) | endpoint-scanner |
| 2 | 테스트 생성 + 실행 | test-writer |
| 3 | AI 리뷰 | test-reviewer |
| 4 | 승인 (review → done) | 메인 세션 |

각 Phase의 세부 흐름은 `commands/qa.md`의 test-coverage 섹션 참조.

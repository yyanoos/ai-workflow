# 세션 문서 생성기

현재 세션에서 수행한 작업을 요약하여 핸드오프 문서를 생성한다.
다른 세션이나 다음 작업자가 현재 상태를 빠르게 파악할 수 있도록.

인자: $ARGUMENTS
- 없으면: 현재 세션 전체 요약
- `--format brief`: 간략 요약 (5줄 이내)
- `--format handoff`: 인수인계용 상세 문서

---

## 실행 흐름

### 1. 정보 수집

아래 소스에서 현재 상태를 수집한다:

**git 상태**:
- 현재 브랜치
- 최근 커밋 이력 (이 세션에서 생성한 것)
- uncommitted changes
- stash 상태

**프로젝트 상태**:
- `.ai-company/project.json` (activeWork)
- `.ai-company/dev/*/status.json` (진행 중 기능)
- `.ai-company/qa/coverage/endpoints.json` (QA 진행률)
- `.ai-company/evolve/config.json` (evolve 설정)

### 2. 문서 생성

#### brief 형식

```
[세션 요약] 2026-04-12
  브랜치: feature/board-crud
  수행: 게시판 CRUD — Phase 3 완료 (GREEN)
  다음: /dev 실행하면 Phase 4 (코드 리뷰) 진행
  미완료: BoardService 예외 처리 TODO 1건
```

#### handoff 형식 (기본값)

`.ai-company/session-log-{날짜}-{시간}.md` 에 저장:

```markdown
# 세션 기록: {날짜} {시간}

## 수행한 작업
- [기능명] Phase N 완료 (결과)
- 파일 변경 목록

## 현재 상태
- 브랜치: feature/{slug}
- /dev status: {status}
- 테스트: N/N 통과

## 알려진 이슈
- (발견했지만 해결하지 않은 문제)

## 다음 단계
- /dev 실행 → Phase N+1
- 또는 수동으로 해야 할 작업

## 의사결정 기록
- (이 세션에서 내린 판단과 근거)
```

### 3. 출력

생성된 문서를 사용자에게 보여준다.
handoff 형식은 파일로도 저장하고, brief는 화면 출력만 한다.

---

## 하지 말 것

- 코드를 수정하지 않는다
- 프로젝트 상태를 변경하지 않는다
- 추측으로 작업 내용을 기록하지 않는다 — git log와 상태 파일에서 확인된 것만

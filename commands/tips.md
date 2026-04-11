# Claude Code 기능 가이드

현재 상황에 맞는 Claude Code 기능을 안내한다.

인자: $ARGUMENTS
- 없으면: 현재 프로젝트 상태에서 유용한 기능 추천
- 키워드: `hooks`, `agents`, `plan`, `loop`, `schedule`, `multi-session`, `all`

---

## $ARGUMENTS 없을 때

`.ai-company/project.json`과 현재 상태를 분석하여 지금 쓸만한 기능 3개를 추천한다.

예시 출력:
```
현재 상태: /dev board-crud (Phase 3 — 구현 중)

추천 기능:
  1. 멀티 세션 — 다른 터미널에서 /dev "다른 기능" 병렬 개발 가능
  2. 플랜모드 (shift+tab) — 복잡한 구현 전 설계 검토
  3. /evolve — 자기 전에 실행하면 테스트 보강/코드 정리 자동

자세히 보기: /tips multi-session, /tips plan, /tips evolve
```

---

## hooks

```
hooks란?
  특정 이벤트 발생 시 자동으로 실행되는 셸 명령어.
  settings.json에 설정한다.

설정 위치: .claude/settings.json (프로젝트별) 또는 ~/.claude/settings.json (글로벌)

예시:
  {
    "hooks": {
      "preCommit": "npm run lint",
      "postCommit": "echo '커밋 완료' | curl -X POST $SLACK_WEBHOOK",
      "onFileChange": "npm run test -- --changed"
    }
  }

활용 예:
  - 커밋 전 자동 lint/format
  - 커밋 후 Slack 알림
  - 파일 변경 시 관련 테스트 자동 실행
  - PR 생성 시 특정 스크립트 실행

설정하기: "hooks 설정해줘" 또는 자세한 방법은 Claude Code 문서 참조
```

---

## agents (서브에이전트)

```
서브에이전트란?
  메인 세션의 컨텍스트를 보호하면서 무거운 작업을 독립 실행하는 하위 AI.
  작업 완료 후 결과만 메인에 반환.

ai-workflow에서의 활용:
  - /dev Phase 2: spec-test-writer 에이전트가 테스트 작성
  - /dev Phase 3: implementer 에이전트가 구현
  - /dev Phase 4: code-reviewer 에이전트가 리뷰
  - /qa Phase 2: test-writer 에이전트가 테스트 생성+실행

장점:
  - 메인 세션 컨텍스트 윈도우 보호
  - 각 에이전트는 전문 역할에 집중
  - 실패해도 메인에 영향 없음

직접 활용:
  "이 작업 서브에이전트로 돌려줘" — 무거운 탐색/분석 작업 위임 가능
```

---

## plan (플랜모드)

```
플랜모드란?
  코드 수정 전에 먼저 분석/설계만 하는 모드.
  파일 수정 도구가 잠기고, 읽기/검색만 가능.

진입/퇴장: shift+tab

활용 시나리오:
  - 복잡한 리팩토링 전 영향 범위 파악
  - 아키텍처 결정 전 현재 구조 분석
  - 버그 원인 추적 (수정하지 않고 분석만)
  - 대규모 변경의 단계별 계획 수립

ai-workflow에서:
  - /dev Phase 1(spec 작성) 전에 플랜모드로 기존 코드 분석하면 더 정확한 spec
  - /evolve 방향 결정 전 현재 상태 파악
```

---

## loop

```
/loop이란?
  슬래시 커맨드를 주기적으로 반복 실행.

사용법:
  /loop 10m /qa         ← 10분마다 /qa 실행
  /loop 5m /evolve --status  ← 5분마다 evolve 상태 확인
  /loop 30m /who        ← 30분마다 현재 추천 확인

활용:
  - /qa 테스트 커버리지 구축 자동화 (승인만 해주면 계속 진행)
  - 모니터링 (서버 상태, 빌드 상태 주기 확인)
  - /evolve 진행 상황 주기 체크
```

---

## schedule

```
/schedule이란?
  크론 기반으로 원격 에이전트를 예약 실행.
  컴퓨터가 꺼져있어도 클라우드에서 실행됨.

활용:
  - 매일 새벽 /evolve 자동 실행
  - 주 1회 /security 보안 스캔
  - 매일 아침 /who 상태 요약 → 알림
```

---

## multi-session (멀티 세션)

```
멀티 세션이란?
  터미널을 여러 개 열어 각각 Claude Code 실행.
  각 세션은 독립적으로 동작.

ai-workflow에서:
  - 세션 1: /dev "게시판 CRUD" (feature/board-crud 브랜치)
  - 세션 2: /dev "알림 기능" (feature/notification 브랜치)
  - 세션 3: /evolve --focus test (evolve/2026-04-12 브랜치)
  
  → 각각 독립 브랜치에서 작업, 파일 충돌은 impact-analyzer가 감지

주의:
  - /qa는 단일 세션 권장 (endpoints.json 공유 상태)
  - /evolve는 토큰 예산 공유 (글로벌 evolve-budget.json)
```

---

## all (전체 치트시트)

전체 기능을 한눈에:

| 기능 | 키/명령어 | 한줄 설명 |
|------|-----------|-----------|
| 플랜모드 | `shift+tab` | 수정 없이 분석만 |
| Extended Thinking | 자동 | 복잡한 문제에 깊이 생각 |
| 서브에이전트 | 자동 | 무거운 작업 독립 실행 |
| hooks | settings.json | 이벤트 기반 자동 실행 |
| /loop | `/loop 10m /cmd` | 주기적 반복 |
| /schedule | `/schedule` | 크론 예약 (원격) |
| 멀티 세션 | 터미널 여러 개 | 병렬 작업 |
| 백그라운드 | 자동 | 긴 작업을 뒤에서 |
| /compact | `/compact` | 컨텍스트 정리 |
| /clear | `/clear` | 대화 초기화 |

# Claude Code 기능 가이드

현재 상황에 맞는 Claude Code 기능을 안내한다.

인자: $ARGUMENTS
- 없으면: 현재 프로젝트 상태에서 유용한 기능 3개 추천
- 키워드: `hooks`, `agents`, `plan`, `loop`, `schedule`, `multi-session`, `all`

---

## $ARGUMENTS 없을 때

`.ai-company/project.json`과 현재 상태를 분석하여 지금 쓸만한 기능 3개를 추천한다.

---

## 키워드별 안내

### hooks
이벤트 발생 시 자동 실행되는 셸 명령어. `settings.json`에 설정.
활용: 커밋 전 lint, 커밋 후 Slack 알림, 파일 변경 시 테스트 실행.

### agents (서브에이전트)
메인 세션 컨텍스트를 보호하면서 무거운 작업을 독립 실행하는 하위 AI.
ai-workflow에서: /dev Phase 2~4, /qa Phase 2~3에서 자동 사용.
직접: "이 작업 서브에이전트로 돌려줘"로 위임 가능.

### plan (플랜모드)
코드 수정 전 분석/설계만 하는 모드. `shift+tab`으로 진입/퇴장.
활용: 리팩토링 전 영향 분석, 아키텍처 결정, 버그 원인 추적.

### loop
슬래시 커맨드를 주기적 반복 실행. `/loop 10m /qa`
활용: QA 자동화 (승인만 해주면 계속), 모니터링, evolve 상태 체크.

### schedule
크론 기반 원격 에이전트 예약. 컴퓨터 꺼져있어도 클라우드에서 실행.

### multi-session
터미널 여러 개 열어 독립 작업. /dev는 복수 세션 가능, /qa는 단일 권장.

---

## all (치트시트)

| 기능 | 키/명령어 | 한줄 설명 |
|------|-----------|-----------|
| 플랜모드 | `shift+tab` | 수정 없이 분석만 |
| Extended Thinking | 자동 | 복잡한 문제에 깊이 생각 |
| 서브에이전트 | 자동 | 무거운 작업 독립 실행 |
| hooks | settings.json | 이벤트 기반 자동 실행 |
| /loop | `/loop 10m /cmd` | 주기적 반복 |
| /schedule | `/schedule` | 크론 예약 (원격) |
| 멀티 세션 | 터미널 여러 개 | 병렬 작업 |
| /compact | `/compact` | 컨텍스트 정리 |
| /clear | `/clear` | 대화 초기화 |

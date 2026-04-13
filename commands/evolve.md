# 자가발전 모드

실행된 프로젝트를 자율적으로 성장시킨다. 별도 브랜치에서 작업하고, PR + HTML 리포트로 사람에게 제출한다.

인자: $ARGUMENTS
- 없으면: 이전 config 유지 또는 자율 판단
- 방향 지정: `"테스트 커버리지 올려"`
- 프리셋: `--focus test`
- 복수 영역: `--focus test,security,"랜딩페이지 카피"`
- 종료 조건: `--until "커버리지 80%"`, `--max-commits 5`, `--max-time 2h`
- 상태 확인: `--status`
- 중단: `--stop`
- 예산 확인: `--budget`
- 회고: `--retro` (PR 거절/부분승인 후 피드백 수집)

---

## 핵심 원칙

1. **사용자 토큰 보장**: 사용자 평소 사용량은 성역. 남는 여유분에서만 작업.
2. **별도 브랜치 + Worktree 격리**: main/master 직접 수정 금지. `evolve/{세션ID}` 브랜치를 git worktree로 물리적으로 분리된 디렉토리에서 작업.
3. **사람 승인 필수**: 자동 merge 절대 금지. PR + HTML before/after 리포트로 제출.
4. **멀티 프로젝트 공정 분배**: 여러 프로젝트에서 동시 실행 시 독점 불가.

---

## 실행 흐름

### 1. 시작

```
/evolve "테스트 커버리지 올려. 특히 member 서비스"
/evolve --focus test,security --max-time 2h
/evolve --focus "회원 서비스 리팩토링","보안 점검" --until "TODO 0개"
```

### 2. 초기화 (또는 상태 복원)

> **ScheduleWakeup 후에는 대화 컨텍스트가 완전히 사라진다.** 깨어날 때마다 새 세션이므로, 모든 상태는 파일에서 복원해야 한다.

#### 2-A. 기존 세션 복원 (continuousMode 감지)

`.ai-company/evolve/sessions/` 스캔 → `config.json`에 `continuousMode: true` + `status: "running"` 또는 `"paused"` 세션이 존재하는 경우:

1. 해당 config.json 로드
2. analysis.json 로드 (범위 분석 결과)
3. tracking.json 로드
4. `status == "paused"` → 현재 시각이 peakHours 밖인지 확인
   - 아직 peakHours → ScheduleWakeup(3600s) → 끝
   - peakHours 끝남 → status → `"running"`
5. worktree 경로 확인 → 해당 경로에서 다음 태스크 이어서 실행
6. **초기화/범위 분석 전부 스킵** → 바로 작업 사이클 진입

#### 2-B. 신규 세션 (기존 세션 없음)

1. `~/.claude/evolve-budget.json` 읽기 (글로벌 토큰 예산)
2. `~/.claude/evolve-global-rules.json` 읽기 (글로벌 학습 룰. 없으면 무시)
3. `.ai-company/evolve/learnings.json` 읽기 (프로젝트 학습. 없으면 무시)
4. **이전 evolve PR 상태 확인** (`gh pr list`로 closed/not-merged 감지)
   - 거절된 PR 발견 → **자동 회고 인터뷰 실행** → 학습 저장 → 계속 진행
5. **세션ID 생성**: `{날짜}_{작업내용-slug}` (예: `2026-04-12_test-coverage`). 작업내용을 kebab-case로 변환. 같은 날짜+내용 충돌 시 숫자 접미사(`-2`).
6. activeSessions에 현재 세션 등록 (세션ID 포함)
7. 할당량 계산 (다른 활성 세션과 공정 분배)
8. `.ai-company/evolve/sessions/{세션ID}/config.json` 생성 (방향, 종료조건, `continuousMode: true`)
9. `.ai-company/evolve/sessions/{세션ID}/tracking.json` 생성 (브랜치/PR/머지 상태 추적)
10. **Worktree 생성**: `git worktree add ../{프로젝트명}-evolve-{세션ID} -b evolve/{세션ID}`
    - 예: `git worktree add ../ai-workflow-evolve-2026-04-12_test-coverage -b evolve/2026-04-12_test-coverage`
    - 이후 모든 작업은 이 worktree 경로에서 수행
11. 범위 분석 실행 → 결과를 `.ai-company/evolve/sessions/{세션ID}/analysis.json`에 저장

### 3. 작업 사이클 (연속 실행)

한 세션에서 태스크 1개를 수행하고, `ScheduleWakeup`으로 다음 세션을 예약한다.
세션 간 상태는 config.json으로 전달된다.

```
태스크 수행:
  1. config.json에서 tasksRemaining의 첫 번째 태스크 꺼냄
  2. analysis.json에서 해당 태스크의 컨텍스트 로드
  3. learnings.json의 거절 패턴에 해당하면 방식 변경 또는 스킵
  4. 태스크 수행 → 커밋
     - 성공 → tasksCompleted에 추가, consecutiveFailures = 0
     - 실패 → 에러 핸들링 (아래 참조)
  5. config.json 업데이트 (cycle 필드)
  6. tracking.json에 사이클 기록 추가

종료 판정:
  영구 종료 조건 충족? → 전문가 리뷰 → PR + 리포트 → 끝
  일시중지 조건 충족? → ScheduleWakeup(재개 시점 delay) → 끝
  둘 다 아님? → ScheduleWakeup(config.wakeupDelay || 270s) → 끝
```

#### 에러 핸들링 (무한루프 방지)

```
태스크 실패 시:
  1. consecutiveFailures++
  2. 해당 태스크의 attempts++
  3. 에러 내용을 tracking.json에 기록

분기:
  - 같은 태스크 3회 실패 → failedTasks에 추가 (skipped: true) → 다음 태스크로
  - 전체 연속 5회 실패 → 루프 중단 → 완료된 분량으로 부분 PR 생성
  - 태스크 성공 → consecutiveFailures = 0 (리셋)
```

#### ScheduleWakeup 호출 규격

```
ScheduleWakeup({
  delaySeconds: config.wakeupDelay || 270,
  reason: "evolve {sessionId} 사이클 {N}/{total}, 다음: {taskName}",
  prompt: "/evolve"
})
```

> **왜 270s인가?** 프롬프트 캐시 TTL이 5분(300s). 270s면 캐시 안에서 깨어나므로 비용/속도 효율적. 300s 이상은 캐시 미스. wakeupDelay는 config.json에서 변경 가능.

### 4. 전문가 리뷰 (PR 제출 전 필수)

작업 사이클 완료 후, PR을 만들기 **전에** 변경 내용에 맞는 전문가 리뷰를 받는다.

1. **리뷰어 선정**: 변경 내용에 따라 적합한 서브에이전트를 선택
   - 코드 변경 → `code-reviewer`
   - 테스트 변경 → `test-reviewer`
   - 문서/구조 변경 → `code-reviewer` (구조 리뷰 관점)
   - 복수 영역 → 해당 영역별 리뷰어 병렬 실행
2. **리뷰 실행**: 서브에이전트에 변경 파일과 변경 의도를 전달
3. **피드백 반영**: major 지적은 반드시 수정 후 재커밋. minor는 판단하여 반영.
4. **재리뷰**: major 수정 시 해당 리뷰어 재실행 (최대 3회 피드백 루프)
   - 3회 후에도 major 잔존 → 해당 변경을 revert하고 나머지만 PR에 포함

### 5. 종료 판정

매 사이클 끝에 실행. 결과에 따라 루프를 계속하거나 멈춘다.

#### 영구 종료 (ScheduleWakeup 호출 안 함 → PR + 리포트)

| 조건 | 판정 방식 |
|------|----------|
| `maxCommits` 도달 | `cycle.current >= stopConditions.global.maxCommits` |
| `maxTime` 초과 | `now - startedAt >= maxTime` |
| `tasksRemaining` 빈 배열 | 모든 태스크 완료 |
| 예산 소진 (일일/주간) | `evolve-budget.json` 확인 |
| 연속 실패 임계치 초과 | `cycle.consecutiveFailures >= 5` → 부분 PR 생성 |
| goal 달성 | 아래 "goal 판정" 참조 |

**goal 판정 방식:**
- **측정 가능** ("커버리지 80%", "TODO 0개"): 커맨드 실행으로 수치 확인. 매 사이클 판정.
- **정성적** ("코드 품질 개선"): 전체 태스크의 70% 완료 후 1회만 판정. 미달성이면 나머지 계속.

#### 일시중지 (ScheduleWakeup으로 재개 예약)

| 조건 | 동작 |
|------|------|
| peakHours 진입 | config.json status → `"paused"`, ScheduleWakeup(peakHours 종료까지, 최대 3600s) |
| 시간 한도 부족 (hourly) | ScheduleWakeup(다음 시간까지 남은 초, 최대 3600s) |

**peakHours 재개 흐름:**
```
peakHours 진입 감지:
  1. config.json status → "paused"
  2. peakHours 종료 시점까지 남은 초 계산
  3. 남은 초 ≤ 3600 → ScheduleWakeup(남은 초)
  4. 남은 초 > 3600 → ScheduleWakeup(3600) → 깨어나서 재확인

깨어났을 때 (2-A에서 처리):
  1. config.json 로드 → status == "paused"
  2. 현재 시각이 peakHours 밖? → status → "running", 태스크 실행
  3. 아직 peakHours? → 다시 ScheduleWakeup
```

#### 영구 종료 시 실행

1. 모든 변경사항으로 `.ai-company/evolve/sessions/{세션ID}/report.html` 생성
2. PR 생성 (`evolve/{세션ID}` → main). PR 제목에 세션ID 포함.
3. config.json status → `"done"`, tracking.json 업데이트 (status → `pr_created`, prNumber, prUrl 기록)
4. `~/.claude/evolve-budget.json`에서 해당 세션을 activeSessions에서 제거
5. Worktree 정리: `git worktree remove ../{프로젝트명}-evolve-{세션ID}`
6. **ScheduleWakeup 호출 안 함** → 루프 종료

---

## 방향성 (--focus)

### 프리셋

| 프리셋 | 대상 |
|--------|------|
| `test` | 테스트 커버리지 보강 (Dev + QA) |
| `performance` | N+1, 불필요한 조회, 인덱스 (Dev) |
| `security` | OWASP, 인증/인가, 입력 검증 (Security + Dev) |
| `cleanup` | 데드코드, TODO, 미사용 import (Dev) |
| `docs` | PROJECT_CONTEXT, CLAUDE.md 최신화 (전체) |
| `marketing` | 카피, SEO, 채널 전략 (Marketing) |
| `design` | 디자인 시스템 일관성, 접근성 (Design) |
| `all` | 전 부서 순회 (기본값) |

### 자유입력

```
/evolve --focus "회원 서비스 edge case","결제 로직 안정화"
```

- 쉼표로 구분, 따옴표 안에 띄어쓰기 허용
- 프리셋과 자유입력 혼용 가능
- AI가 자연어로 이해

### 가중치

- 비중 미지정 → 균등 배분
- 자연어로 암시: `"테스트에 집중해줘"` → AI가 판단
- 명시적: `"test 50%, security 30%, marketing 20%"`

---

## 종료 조건

```
/evolve --until "커버리지 80%"           ← 목표 달성
/evolve --max-commits 5                  ← 커밋 수 제한
/evolve --max-tokens 50000               ← 토큰 제한
/evolve --max-time 2h                    ← 시간 제한
```

focus별 조건 (자연어):
```
/evolve --focus test,security "test는 커버리지 80% 달성하면 끝, security는 OWASP 통과하면 끝"
```

동작:
- focus별 조건 달성 → 해당 focus 종료 → 남은 토큰 다른 focus에 재배분
- 글로벌 조건(시간/커밋/토큰) 먼저 도달 → 전체 종료
- 조건 없으면 → 예산 소진 또는 개선 대상 없을 때까지

---

## 토큰 예산 관리

### 글로벌 파일: `~/.claude/evolve-budget.json`

모든 프로젝트의 evolve가 이 파일 하나를 공유한다.

### 사용자 보장량 계산

```
userReserve(시간) = user.hourlyAverage * 1.3   ← 30% 여유
userReserve(일)   = user.dailyAverage  * 1.3
userReserve(주)   = user.weeklyAverage * 1.3

totalAvailable = min(
  plan.hourlyLimit - userReserve(시간),
  plan.dailyLimit  - userReserve(일),
  plan.weeklyLimit - userReserve(주)
)
```

### 멀티 프로젝트 공정 분배

```
내 할당량 = totalAvailable / activeSessions 수

매 작업 단위마다:
  1. evolve-budget.json 다시 읽기
  2. activeSessions 변동 확인
  3. 할당량 재계산
  4. 초과 시 대기
```

먼저 시작해도 독점 불가. 새 세션 합류 → 전체 재조율.

### 사용자 사용량 학습

- 매 세션 종료 시 사용량 기록
- 지수이동평균(EMA)으로 최근 패턴에 빠르게 적응
- peakHours(사용자가 주로 쓰는 시간대) 자동 감지 → 해당 시간대 자동 일시중지

### 한도 도달 시

1. 시간 한도 부족 → 다음 시간까지 대기 (최대 60분)
2. 일일 한도 부족 → 자정까지 대기
3. 주간 한도 부족 → 주간 리셋까지 대기
4. `waitingUntil` 기록 → 회복 후 자동 재시작

---

## 변경사항 보고

### HTML 리포트: `.ai-company/evolve/sessions/{세션ID}/report.html`

자가발전 완료 시 자동 생성:
- 요약: 변경 항목 목록
- 항목별 before/after diff (코드 하이라이팅)
- 변경 사유 설명
- 영향 분석 (사이드이펙트 여부)
- 승인/거절/부분승인 가이드

### 사용자 확인 흐름

1. 자가발전 완료 → PR 생성 + HTML 리포트 생성
2. 안내: "자가발전 완료. report: .ai-company/evolve/sessions/{세션ID}/report.html"
3. 사용자가 브라우저에서 before/after 확인
4. 승인 → merge
5. 부분 승인 → 해당 커밋만 cherry-pick
6. 거절 → 브랜치 삭제

---

## 부서별 개선 대상

| 부서 | 예시 |
|------|------|
| Strategy | 경쟁사 동향 업데이트, 시장 데이터 갱신 |
| Legal | 법률 체크리스트 최신화, 약관 누락 조항 |
| Product | PRD 엣지케이스, 사용자 여정 빠진 경로 |
| Design | 디자인 시스템 일관성, 접근성, 컬러 대비 |
| Dev | 테스트 커버리지, SOLID 위반, 성능, TODO |
| QA | 테스트 엣지케이스, 테스트 데이터 현실성 |
| DevOps | CI/CD 최적화, 보안 취약 의존성 |
| Security | OWASP 재실행, 새 엔드포인트 보안 검증 |
| Marketing | 카피 A/B 변형, SEO 메타태그, 경쟁사 분석 |
| Ops | 대시보드 쿼리 최적화, CS FAQ 최신화 |

---

## 설정 파일

### .ai-company/evolve/sessions/{세션ID}/config.json (세션별)

세션마다 독립된 디렉토리를 갖는다. 서로 간섭하지 않는다.

```json
{
  "sessionId": "2026-04-12_auth-edge-case",
  "startedAt": "2026-04-12T23:15:00+09:00",
  "focus": ["test", "security"],
  "direction": "인증 쪽 edge case 위주",
  "priorities": ["인증 관련 우선", "happy path보다 edge case"],
  "exclude": ["telegram-bot"],
  "continuousMode": true,
  "wakeupDelay": 270,
  "status": "running",
  "worktreePath": "../ai-workflow-evolve-2026-04-12_auth-edge-case",
  "cycle": {
    "current": 3,
    "tasksCompleted": ["task-1", "task-2", "task-3"],
    "tasksRemaining": ["task-4", "task-5"],
    "failedTasks": [],
    "revertedCommits": [],
    "consecutiveFailures": 0,
    "focusProgress": {
      "test": { "completed": 2, "total": 3, "goalMet": false },
      "security": { "completed": 1, "total": 2, "goalMet": false }
    },
    "lastWakeup": "2026-04-12T23:30:00+09:00"
  },
  "stopConditions": {
    "global": { "maxCommits": 10, "maxTime": "4h" },
    "perFocus": {
      "test": { "goal": "커버리지 80%" },
      "security": { "goal": "OWASP 통과" }
    }
  }
}
```

**config.json status 값:**
| status | 의미 |
|--------|------|
| `running` | 작업 진행 중 (다음 ScheduleWakeup 예약됨) |
| `paused` | peakHours 또는 예산 대기 중 |
| `completing` | 전문가 리뷰 + PR 생성 중 |
| `done` | PR 생성 완료 |
| `failed` | 연속 실패로 중단 (부분 PR 생성됨) |

### .ai-company/evolve/sessions/{세션ID}/analysis.json (범위 분석 결과)

신규 세션의 범위 분석(초기화 2-B 단계) 결과를 저장. 이후 매 사이클에서 태스크 컨텍스트를 복원할 때 참조한다.

```json
{
  "departments": ["Dev", "QA"],
  "tasks": [
    {
      "id": "task-1",
      "description": "MemberService 인증 edge case 테스트 추가",
      "department": "Dev",
      "priority": "high",
      "context": "현재 happy path만 테스트됨, 만료 토큰/잘못된 형식 미커버"
    }
  ],
  "flaggedItems": [],
  "generatedAt": "2026-04-12T23:20:00+09:00"
}
```

### .ai-company/evolve/sessions/{세션ID}/tracking.json (브랜치/PR 추적)

세션의 브랜치 위치, PR 상태, 머지/반려 여부를 추적한다. evolve 외부에서도 이 파일만 보면 해당 작업의 현재 상태를 파악할 수 있다.

```json
{
  "sessionId": "2026-04-12_auth-edge-case",
  "branch": "evolve/2026-04-12_auth-edge-case",
  "baseBranch": "master",
  "status": "pr_created",
  "pr": {
    "number": 42,
    "url": "https://github.com/owner/repo/pull/42",
    "createdAt": "2026-04-12T23:45:00+09:00"
  },
  "result": null,
  "history": [
    { "at": "2026-04-12T23:15:00+09:00", "event": "branch_created" },
    { "at": "2026-04-12T23:40:00+09:00", "event": "work_completed", "commits": 5 },
    { "at": "2026-04-12T23:45:00+09:00", "event": "pr_created", "prNumber": 42 }
  ]
}
```

**status 값:**
| status | 의미 |
|--------|------|
| `working` | 작업 진행 중 |
| `pr_created` | PR 생성됨, 리뷰 대기 |
| `merged` | PR 머지 완료 |
| `rejected` | PR 반려 (closed without merge) |
| `partial` | 부분 승인 (일부 커밋만 cherry-pick) |

**result 값 (종료 후):**
```json
{
  "outcome": "merged",
  "mergedAt": "2026-04-13T10:00:00+09:00",
  "mergedBy": "yeonwoo"
}
```
또는:
```json
{
  "outcome": "rejected",
  "closedAt": "2026-04-13T10:00:00+09:00",
  "reason": "scope_excess",
  "retroDone": true
}
```

### ~/.claude/evolve-budget.json (글로벌)

```json
{
  "plan": { "hourlyLimit": 500000, "dailyLimit": 5000000, "weeklyLimit": 20000000 },
  "user": {
    "hourlyAverage": 40000,
    "dailyAverage": 400000,
    "weeklyAverage": 2000000,
    "peakHours": [10, 11, 14, 15, 16],
    "history": { "daily": [], "weekly": [] }
  },
  "evolve": {
    "reserve": 0.3,
    "totalAvailable": 1500000,
    "activeSessions": [
      {
        "sessionId": "2026-04-12_auth-edge-case",
        "project": "ai-workflow",
        "projectPath": "/Users/USER/Desktop/project/ai-workflow",
        "focus": ["test", "security"],
        "startedAt": "2026-04-12T23:15:00+09:00"
      }
    ]
  }
}
```

---

## --status

```
/evolve --status
```

```
자가발전 상태:
  프로젝트: jhin-eye
  활성 세션:
    [1] 2026-04-12_auth-edge-case (evolve/2026-04-12_auth-edge-case)
        방향: test, security (테스트에 집중)
        상태: running (사이클 3/10, 다음 wakeup 270s 후)
        진행: 3/10 커밋 (실패 0, 스킵 0)
        다음: MemberService 인증 edge case 테스트
    [2] 2026-04-12_query-optimization (evolve/2026-04-12_query-optimization)
        방향: performance
        상태: paused (peakHours 대기, 17:00 재개 예정)
        진행: 3/5 커밋
  완료 세션:
    [3] 2026-04-11_dead-code-cleanup → done, PR #48 (merged)
    [4] 2026-04-10_input-validation → failed, PR #45 (부분 PR, 연속 실패)
  총 토큰: 45,000 / 150,000 사용
```

---

## 제약

- **별도 브랜치에서만 작업** (main/master 직접 수정 금지)
- 기존 동작을 깨뜨리는 변경 금지 (테스트 통과 필수)
- **모든 변경은 PR + HTML 리포트** → 사람 승인 후에만 merge
- 사용자 토큰 절대 침범 안 함 (사용자 우선 원칙)
- 자동 merge 절대 금지
- peakHours에는 자동 일시중지
- 사용자 세션 활성 감지 시 즉시 양보

## 회고 & 자체진화 (`--retro`)

PR이 거절되거나 부분승인될 때 실행한다. evolve가 자기 실수에서 배워서 다음에 같은 실수를 반복하지 않도록 한다.

### 실행

```
/evolve --retro                    ← 가장 최근 evolve PR 기준
/evolve --retro #42                ← 특정 PR 번호 지정
```

### 회고 흐름

1. **PR 상태 확인**: `gh pr view`로 해당 PR의 상태, 리뷰 코멘트, 커밋 목록 수집
2. **사용자 인터뷰**: 아래 질문을 순서대로 진행 (AskUserQuestion 사용)

```
Q1. 이 PR에서 거절/수정한 항목은 뭐였나요?
    (커밋 목록을 보여주며) 어떤 커밋이 문제였는지 번호로 골라주세요.

Q2. 왜 거절했나요?
    - a) 불필요한 변경 (안 건드려도 됐음)
    - b) 방향이 틀림 (의도를 잘못 이해)
    - c) 품질 미달 (코드가 구림)
    - d) 범위 초과 (너무 많이 건드림)
    - e) 기타 (직접 설명)

Q3. 어떻게 했으면 좋았을까요?
    (자유 답변)

Q4. 이 피드백이 이 프로젝트에만 해당하나요, 아니면 모든 프로젝트에 적용되나요?
    - a) 이 프로젝트만
    - b) 전체 프로젝트 공통
```

3. **학습 저장**: `.ai-company/evolve/learnings.json`에 추가
4. **요약 출력**: "학습 저장 완료. 다음 evolve부터 반영됩니다."

### 학습 파일: `.ai-company/evolve/learnings.json`

```json
{
  "learnings": [
    {
      "date": "2026-04-12",
      "pr": "#42",
      "rejected_commits": ["a1b2c3d: 불필요한 import 정리"],
      "reason": "scope_excess",
      "detail": "cleanup 포커스가 아닐 때 import 정리하지 말 것",
      "preference": "변경 범위를 focus에 명시된 영역으로 엄격히 제한",
      "scope": "project"
    },
    {
      "date": "2026-04-13",
      "pr": "#45",
      "rejected_commits": ["d4e5f6a: 에러 메시지 한글화"],
      "reason": "direction_wrong",
      "detail": "에러 메시지는 영어로 유지 (로그 검색 때문)",
      "preference": "사용자 facing 텍스트만 한글화, 에러/로그는 영어",
      "scope": "global"
    }
  ],
  "rules": [
    "cleanup 포커스가 아닐 때 import/formatting 변경 금지",
    "에러 메시지, 로그 메시지는 영어 유지"
  ]
}
```

### 학습 적용 방식

evolve 실행 시 `learnings.json`을 읽고:

1. **rules**: 작업 사이클의 필터로 사용. 룰에 위배되는 변경은 아예 하지 않음
2. **learnings**: reason별 패턴을 파악하여 작업 성향 조정
   - `scope_excess`가 많으면 → 변경 범위를 더 좁게
   - `direction_wrong`이 많으면 → 기존 코드의 의도를 더 깊이 분석 후 작업
   - `unnecessary`가 많으면 → 영향도 임계값을 높여서 사소한 개선 스킵
   - `quality_low`가 많으면 → 변경 후 자체 코드리뷰 단계 추가
3. **scope=global인 학습**: `~/.claude/evolve-global-rules.json`에도 복사하여 다른 프로젝트에서도 적용

### 자동 회고 (거절 감지 시 자동 실행)

`/evolve` 실행 시 초기화 단계에서 이전 evolve PR 상태를 `gh pr list --state closed`로 확인한다.

- **PR이 closed(not merged)**: 거절로 간주 → `tracking.json` status를 `rejected`로 업데이트 → 자동으로 회고 인터뷰 시작
- **PR에 changes_requested 리뷰**: 부분 거절로 간주 → `tracking.json` status를 `partial`로 업데이트 → 자동으로 회고 인터뷰 시작
- **PR이 merged**: 성공 → `tracking.json` status를 `merged`로 업데이트 → 회고 스킵, 바로 다음 evolve 진행

사용자가 `--retro`를 직접 치지 않아도, 거절된 PR이 감지되면 무조건 인터뷰가 시작된다.
회고 완료 후 학습을 저장하고, 이어서 새 evolve 사이클을 시작한다.

**흐름:**
```
/evolve 실행
  → 이전 PR #42 closed(not merged) 감지
  → 자동 회고 인터뷰 (Q1~Q4)
  → learnings.json 저장
  → 학습 반영하여 새 evolve 사이클 시작
```

---

## 멀티세션 격리

같은 프로젝트에서 여러 evolve 세션이 동시에 돌 수 있다. 충돌을 방지하기 위해:

### 세션ID 규칙

- 형식: `{YYYY-MM-DD}_{작업내용-slug}` (예: `2026-04-12_test-coverage`)
- slug는 focus/direction에서 핵심 단어를 추출하여 kebab-case로 생성 (영문, 최대 30자)
- 같은 날짜+slug 충돌 시 숫자 접미사 (`-2`, `-3`)
- 이 ID가 브랜치명, 디렉토리명, activeSessions 키로 사용됨

### 격리되는 자원

| 자원 | 경로/이름 | 격리 방식 |
|------|----------|----------|
| **worktree** | `../{프로젝트명}-evolve-{세션ID}/` | 물리적으로 분리된 디렉토리 |
| 브랜치 | `evolve/{세션ID}` | 세션별 독립 브랜치 |
| config | `.ai-company/evolve/sessions/{세션ID}/config.json` | 세션별 독립 파일 |
| tracking | `.ai-company/evolve/sessions/{세션ID}/tracking.json` | 세션별 독립 파일 |
| analysis | `.ai-company/evolve/sessions/{세션ID}/analysis.json` | 세션별 독립 파일 |
| 리포트 | `.ai-company/evolve/sessions/{세션ID}/report.html` | 세션별 독립 파일 |
| PR | `evolve/{세션ID}` → main | 세션별 독립 PR |

> **Worktree 격리 원칙**
> `git checkout`은 워킹 디렉토리 전체를 교체하므로, 동시에 여러 세션이 다른 브랜치에서 작업할 수 없다.
> `git worktree`는 같은 `.git`을 공유하되 물리적으로 분리된 디렉토리를 생성하여 진정한 병렬 작업을 보장한다.
> evolve 세션, dev 세션, 사용자 작업이 모두 동시에 각자의 브랜치에서 독립적으로 진행된다.

### 공유되는 자원 (읽기 전용 or append-only)

| 자원 | 경로 | 접근 방식 |
|------|------|----------|
| 학습 | `.ai-company/evolve/learnings.json` | **읽기는 자유, 쓰기는 회고 시에만** (회고는 한 세션씩 순차) |
| 예산 | `~/.claude/evolve-budget.json` | 읽기 후 자기 세션만 갱신 (다른 세션 데이터 건드리지 않음) |
| 글로벌 룰 | `~/.claude/evolve-global-rules.json` | append-only |

### 같은 파일 수정 충돌 방지

- 각 세션은 focus가 다르므로 보통 다른 파일을 건드림
- 만약 같은 파일을 수정해야 하면: `git diff`로 다른 evolve 브랜치에서 해당 파일이 변경됐는지 확인 → 변경됐으면 해당 파일 스킵

### Worktree 정리

세션 종료 시 (PR 생성 후) worktree를 정리한다:
```bash
git worktree remove ../{프로젝트명}-evolve-{세션ID}
```
브랜치는 삭제하지 않는다 (PR 머지/반려 후 판단).

---

## 사전 조건

- **Permission 설정 필수**: evolve는 자율 실행 모드이므로 git, gh 등의 Bash 명령에 대해 permission이 auto-allow되어야 한다. `~/.claude/settings.local.json`의 `permissions.allow`에 `Bash(git:*)`, `Bash(gh:*)` 등이 포함되어 있는지 확인. 미설정 시 permission 프롬프트에서 멈춘다.
- 또는 `claude --dangerously-skip-permissions`로 실행.

---

## 하지 말 것

- main/master에 직접 커밋하지 않는다
- 사용자에게 질문하지 않는다 (자기 전에 실행하는 시나리오)
- 토큰 예산을 초과하지 않는다
- 다른 evolve 세션의 할당량을 침범하지 않는다
- 종료조건 달성 후 추가 작업하지 않는다
- 테스트가 깨지는 변경을 커밋하지 않는다

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
2. **별도 브랜치**: main/master 직접 수정 금지. `evolve/{세션ID}` 브랜치에서만.
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

### 2. 초기화

1. `~/.claude/evolve-budget.json` 읽기 (글로벌 토큰 예산)
2. `~/.claude/evolve-global-rules.json` 읽기 (글로벌 학습 룰. 없으면 무시)
3. `.ai-company/evolve/learnings.json` 읽기 (프로젝트 학습. 없으면 무시)
4. **이전 evolve PR 상태 확인** (`gh pr list`로 closed/not-merged 감지)
   - 거절된 PR 발견 → **자동 회고 인터뷰 실행** → 학습 저장 → 계속 진행
5. **세션ID 생성**: `{날짜}_{작업내용-slug}` (예: `2026-04-12_test-coverage`). 작업내용을 kebab-case로 변환. 같은 날짜+내용 충돌 시 숫자 접미사(`-2`).
6. activeSessions에 현재 세션 등록 (세션ID 포함)
7. 할당량 계산 (다른 활성 세션과 공정 분배)
8. `.ai-company/evolve/sessions/{세션ID}/config.json` 생성 (방향, 종료조건)
9. `.ai-company/evolve/sessions/{세션ID}/tracking.json` 생성 (브랜치/PR/머지 상태 추적)
10. `evolve/{세션ID}` 브랜치 생성

### 3. 작업 사이클

```
반복:
  1. 개선 대상 탐색 (focus 방향에 따라)
  2. learnings.json의 거절 패턴에 해당하는 변경은 제외하거나 방식 변경
  3. 우선순위 정렬 (영향도 × 난이도)
  4. 하나 개선 → 커밋
  4. 종료조건 체크 (goal 달성? maxCommits? maxTime?)
  5. 예산 체크:
     - ~/.claude/evolve-budget.json 다시 읽기
     - activeSessions 변동 → 할당량 재계산
     - 할당량 초과 → 대기 (waitingUntil 기록)
     - 회복 → 이어서 진행
  6. 종료조건 미달 + 예산 남음 → 다음 항목으로
```

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

### 5. 종료

1. 모든 변경사항으로 `.ai-company/evolve/sessions/{세션ID}/report.html` 생성
2. PR 생성 (`evolve/{세션ID}` → main). PR 제목에 세션ID 포함.
3. `tracking.json` 업데이트 (status → `pr_created`, prNumber, prUrl 기록)
4. `~/.claude/evolve-budget.json`에서 해당 세션을 activeSessions에서 제거
5. 사용자에게 안내

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
  "stopConditions": {
    "global": { "maxCommits": 10, "maxTime": "4h" },
    "perFocus": {
      "test": { "goal": "커버리지 80%" },
      "security": { "goal": "OWASP 통과" }
    }
  }
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
        상태: working
        진행: 3/10 커밋
        다음: MemberService 인증 edge case 테스트
    [2] 2026-04-12_query-optimization (evolve/2026-04-12_query-optimization)
        방향: performance
        상태: pr_created (#51)
        진행: 5/5 커밋 (완료)
  완료 세션:
    [3] 2026-04-11_dead-code-cleanup → merged (#48)
    [4] 2026-04-10_input-validation → rejected (#45, 회고 완료)
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
| 브랜치 | `evolve/{세션ID}` | 세션별 독립 브랜치 |
| config | `.ai-company/evolve/sessions/{세션ID}/config.json` | 세션별 독립 파일 |
| tracking | `.ai-company/evolve/sessions/{세션ID}/tracking.json` | 세션별 독립 파일 |
| 리포트 | `.ai-company/evolve/sessions/{세션ID}/report.html` | 세션별 독립 파일 |
| PR | `evolve/{세션ID}` → main | 세션별 독립 PR |

### 공유되는 자원 (읽기 전용 or append-only)

| 자원 | 경로 | 접근 방식 |
|------|------|----------|
| 학습 | `.ai-company/evolve/learnings.json` | **읽기는 자유, 쓰기는 회고 시에만** (회고는 한 세션씩 순차) |
| 예산 | `~/.claude/evolve-budget.json` | 읽기 후 자기 세션만 갱신 (다른 세션 데이터 건드리지 않음) |
| 글로벌 룰 | `~/.claude/evolve-global-rules.json` | append-only |

### 같은 파일 수정 충돌 방지

- 각 세션은 focus가 다르므로 보통 다른 파일을 건드림
- 만약 같은 파일을 수정해야 하면: `git diff`로 다른 evolve 브랜치에서 해당 파일이 변경됐는지 확인 → 변경됐으면 해당 파일 스킵

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

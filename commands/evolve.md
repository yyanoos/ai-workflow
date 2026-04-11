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

---

## 핵심 원칙

1. **사용자 토큰 보장**: 사용자 평소 사용량은 성역. 남는 여유분에서만 작업.
2. **별도 브랜치**: main/master 직접 수정 금지. `evolve/{날짜}` 브랜치에서만.
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
2. activeSessions에 현재 프로젝트 등록
3. 할당량 계산 (다른 활성 세션과 공정 분배)
4. `.ai-company/evolve/config.json` 생성/갱신 (방향, 종료조건)
5. `evolve/{날짜}` 브랜치 생성

### 3. 작업 사이클

```
반복:
  1. 개선 대상 탐색 (focus 방향에 따라)
  2. 우선순위 정렬 (영향도 × 난이도)
  3. 하나 개선 → 커밋
  4. 종료조건 체크 (goal 달성? maxCommits? maxTime?)
  5. 예산 체크:
     - ~/.claude/evolve-budget.json 다시 읽기
     - activeSessions 변동 → 할당량 재계산
     - 할당량 초과 → 대기 (waitingUntil 기록)
     - 회복 → 이어서 진행
  6. 종료조건 미달 + 예산 남음 → 다음 항목으로
```

### 4. 종료

1. 모든 변경사항으로 `.ai-company/evolve/report-{날짜}.html` 생성
2. PR 생성 (`evolve/{날짜}` → main)
3. `~/.claude/evolve-budget.json`에서 activeSessions 제거
4. 사용자에게 안내

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

### HTML 리포트: `.ai-company/evolve/report-{날짜}.html`

자가발전 완료 시 자동 생성:
- 요약: 변경 항목 목록
- 항목별 before/after diff (코드 하이라이팅)
- 변경 사유 설명
- 영향 분석 (사이드이펙트 여부)
- 승인/거절/부분승인 가이드

### 사용자 확인 흐름

1. 자가발전 완료 → PR 생성 + HTML 리포트 생성
2. 안내: "자가발전 완료. report: .ai-company/evolve/report-{날짜}.html"
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

### .ai-company/evolve/config.json (프로젝트별)

```json
{
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

### ~/.claude/evolve-budget.json (글로벌)

```json
{
  "plan": { "hourlyLimit": 50000, "dailyLimit": 500000, "weeklyLimit": 2500000 },
  "user": {
    "hourlyAverage": 15000,
    "dailyAverage": 150000,
    "weeklyAverage": 900000,
    "peakHours": [9, 10, 11, 14, 15, 16],
    "history": { "daily": [], "weekly": [] }
  },
  "evolve": {
    "reserve": 0.3,
    "totalAvailable": 105000,
    "activeSessions": []
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
  브랜치: evolve/2026-04-12
  방향: test, security (테스트에 집중)
  진행: 3/10 커밋 (종료조건: maxCommits 10)
  토큰: 23,000 / 52,500 사용
  활성 세션: 2개 (jhin-eye, ai-workflow)
  다음 작업: MemberService 인증 edge case 테스트
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

## 하지 말 것

- main/master에 직접 커밋하지 않는다
- 사용자에게 질문하지 않는다 (자기 전에 실행하는 시나리오)
- 토큰 예산을 초과하지 않는다
- 다른 evolve 세션의 할당량을 침범하지 않는다
- 종료조건 달성 후 추가 작업하지 않는다
- 테스트가 깨지는 변경을 커밋하지 않는다

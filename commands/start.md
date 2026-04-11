# 총괄 오케스트레이터

사용자의 의도를 파악하여 적합한 부서/전문가를 안내한다.

인자: $ARGUMENTS
- 신규 제품: `노인 돌봄 매칭 앱`
- 기존 제품 기능: `알림 기능 추가`
- 특정 작업: `랜딩페이지 만들기`

---

## 실행 흐름

### 1. 프로젝트 상태 파악

`.ai-company/project.json`이 있는지 확인한다.

**있으면 (기존 프로젝트)**:
- project.json 읽기
- completedPhases, activeWork 확인
- $ARGUMENTS가 기존 activeWork와 매칭되는지 확인

**없으면 (신규 프로젝트)**:
- "신규 프로젝트를 시작합니다" 안내
- `.ai-company/` 디렉토리 구조 생성
- project.json 초기화

### 2. 의도 분류

$ARGUMENTS를 분석하여 아래 중 하나로 분류:

| 의도 | 예시 | 라우팅 |
|------|------|--------|
| 신규 제품 | "노인 돌봄 앱", "SaaS 만들기" | /consult strategy → /consult product → /dev |
| 신규 기능 | "알림 기능 추가", "결제 연동" | /consult product 또는 /dev |
| 버그/이슈 | "로그인 안 됨", "느려짐" | /dev 또는 /consult infra |
| 비개발 작업 | "약관 만들기", "로고 디자인" | /consult {부서} |
| 모호함 | 판단 불가 | 질문으로 명확화 |

### 3. 추천 및 안내

분류 결과에 따라 사용자에게 안내:

```
프로젝트: 노인 돌봄 매칭 앱 (신규)

현재 상태: 아직 시작 전

추천 순서:
  1. /consult strategy — 시장조사, 경쟁분석부터 (추천)
  2. /consult product — 바로 기획으로 가기
  3. /dev — 바로 개발 시작

어떤 부서에 맡길까요? /who 로 전체 전문가, /consult {부서} 로 직접 맡기기.
```

기존 프로젝트 + 기능 추가인 경우:
```
프로젝트: 노인 돌봄 매칭 앱 (기존)

현재 진행 중:
  - [dev] 매칭 알고리즘 (status: green)
  - [design] 브랜드 가이드 (status: in-progress)

"알림 기능 추가" 작업:
  추천: /consult product "알림 기능 추가" — PRD 먼저 작성
  또는: /dev "알림 기능 추가" — 바로 개발 시작 (spec 대화부터)
```

### 4. 라우팅

사용자가 부서를 선택하면:
- 해당 부서 커맨드 안내 (예: `/consult strategy "노인 돌봄 매칭 앱"`)
- 또는 사용자가 "추천대로" 하면 첫 번째 추천 실행

---

## project.json 초기화

신규 프로젝트 시:

```json
{
  "name": "$ARGUMENTS에서 추출한 프로젝트명",
  "slug": "kebab-case-slug",
  "phase": "initialized",
  "createdAt": "오늘 날짜",
  "completedPhases": [],
  "activeWork": []
}
```

---

## 하지 말 것

- 부서 업무를 직접 수행하지 않는다 — 안내와 라우팅만
- 사용자가 선택하지 않았는데 임의로 부서를 실행하지 않는다
- project.json 외의 산출물을 생성하지 않는다

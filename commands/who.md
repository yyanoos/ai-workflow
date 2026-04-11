# 전문가 안내

현재 프로젝트 상태를 분석하여 가용한 전문가 목록과 지금 필요한 전문가를 안내한다.

인자: $ARGUMENTS
- 없으면: 전체 목록 + 추천
- 부서명: `dev`, `design` 등 → 해당 부서 상세

---

## 실행 흐름

### 1. 프로젝트 상태 읽기

`.ai-company/project.json`을 읽어 현재 단계와 진행 중인 작업을 파악한다.
없으면 "프로젝트가 초기화되지 않았습니다. /start로 시작하세요." 안내.

### 2. 전체 전문가 목록 출력

```
═══ 가상 회사 전문가 목록 ═══

현재 프로젝트: 노인 돌봄 매칭 앱 (phase: product)

▸ 전략실 (/consult strategy)
  - 비즈니스 분석가, 재무 분석가
  ✓ 완료됨

▸ 법무팀 (/consult legal)
  - 법률 자문, 세무사
  ✓ 완료됨

▸ 기획팀 (/consult product)  ← 지금 여기
  - 프로덕트 매니저, UX 리서처
  ⚡ 진행 중: PRD 작성

▸ 디자인팀 (/consult design)
  - UX/UI/브랜드 디자이너

▸ 개발팀 (/dev)
  - 백엔드/프론트엔드 개발자, 코드 리뷰어
  ⚡ 진행 중: 매칭 알고리즘 (status: green)

▸ QA팀 (/qa)
  - QA 엔지니어 — 테스트 전략, 커버리지 구축

▸ DevOps (/consult devops)
▸ 보안 (/consult security)
▸ 마케팅팀 (/consult marketing)
▸ 운영팀 (/consult ops)
▸ 인프라 (/consult infra)

▸ 공통
  - 영향 분석가 (impact-analyzer) — 변경 전 크로스 영향 분석

───
💡 지금 추천: /consult product — PRD 작성을 이어서 진행
💡 부서 작업 맡기기: /consult {부서} "작업 내용"
```

### 3. 부서 상세 ($ARGUMENTS에 부서명이 있을 때)

```
/who dev
```

```
═══ 개발팀 상세 ═══

전문가:
  - 백엔드 개발자 (implementer) — 테스트를 통과시키는 코드 작성. SOLID 준수.
  - 프론트엔드 개발자 — UI 구현 (준비 중)
  - 코드 리뷰어 (code-reviewer) — 빅테크 시니어 관점 리뷰
  - 테스트 작성자 (spec-test-writer) — 명세 기반 통합 테스트
  - DB 리뷰어 (db-reviewer) — 정규화 검증, 마이그레이션 안전성

워크플로우: /dev "기능설명"
  Phase 1: 구현 명세 (대화형)
  Phase 2: 테스트 작성 (RED)
  Phase 3: 구현 (GREEN)
  Phase 4: 코드 리뷰
  Phase 5: MR 생성

현재 진행 중:
  - 매칭 알고리즘 [matching] (status: green, branch: feature/matching)

개발 원칙: SOLID, DRY, KISS, YAGNI, Clean Architecture
DB 원칙: 3NF 정규화 기본, Flyway 마이그레이션 필수
```

---

## 추천 로직

프로젝트 phase에 따라 "지금 추천"을 결정:

| phase | 추천 |
|-------|------|
| initialized | /consult strategy (시장조사부터) |
| strategy | /consult product (기획으로) |
| product | /consult design 또는 /dev (디자인 필요 여부에 따라) |
| design | /dev (개발 시작) |
| dev | /qa (테스트) 또는 /consult marketing (출시 준비) |
| launched | /consult ops (운영) 또는 /dev (다음 기능) |

activeWork가 있으면 해당 작업 이어서 하기를 우선 추천.

---

## 하지 말 것

- 부서 업무를 직접 수행하지 않는다 — 안내만
- 프로젝트 상태를 변경하지 않는다
- 사용자가 요청하지 않은 부서를 강제로 추천하지 않는다

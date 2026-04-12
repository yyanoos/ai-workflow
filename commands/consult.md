# 전문가 상담

지정된 부서의 전문가에게 작업을 맡긴다.
`/who`에서 안내하는 모든 부서를 커버하는 단일 진입점.

인자: $ARGUMENTS
- 부서 + 작업: `strategy "노인 돌봄 앱 시장 분석"`, `security "인증 로직 보안감사"`
- 작업만: `"약관 만들어줘"` → 자동으로 적합한 부서 판단

---

## 지원 부서

| 부서 키워드 | 역할 | 산출물 위치 |
|-------------|------|-------------|
| `strategy` | 시장조사, 경쟁분석, 비즈니스 모델 | `.ai-company/strategy/` |
| `legal` | 약관, 개인정보처리방침, 법적 체크리스트 | `.ai-company/legal/` |
| `product` | PRD, 사용자 스토리, 로드맵, 페르소나 | `.ai-company/product/` |
| `design` | 와이어프레임, 디자인 시스템, 접근성 | `.ai-company/design/` |
| `security` | OWASP, 보안감사, 취약점 분석 | `.ai-company/security/` |
| `marketing` | 채널 전략, SEO, 카피, 퍼널 | `.ai-company/marketing/` |
| `ops` | 지표 설계, 대시보드, CS FAQ | `.ai-company/ops/` |
| `devops` | CI/CD, 인프라, 배포, 모니터링 | `.ai-company/devops/` |
| `infra` | 서버 진단, DB 관리, 성능 튜닝 | `.ai-company/infra/` |

개발(dev)과 QA는 전용 커맨드(`/dev`, `/qa`)를 사용할 것.

---

## 실행 흐름

### 1. 부서 판단

$ARGUMENTS에서 부서 키워드를 추출한다.
- 명시적: `security "인증 감사"` → security
- 암시적: `"약관 만들어줘"` → legal로 자동 판단
- 모호함: 사용자에게 "어떤 부서가 적합할까요?" 질문

### 2. 전문가 실행

**`domain-expert`** 서브에이전트를 실행한다.

프롬프트에 포함:
- 역할: 판단된 부서명과 전문가 역할
- 작업: 사용자가 지정한 작업 내용
- 프로젝트 컨텍스트: PROJECT_CONTEXT.md 경로 (있으면)
- 산출물 경로: 부서별 디렉토리

### 3. 결과 보고

에이전트 결과를 사용자에게 보여준다.
- **DONE**: 산출물 파일 경로와 요약
- **NEEDS_INPUT**: 추가 정보 필요 — 사용자에게 질문

### 4. project.json 연동

`.ai-company/project.json`의 activeWork에 기록:
```json
{
  "department": "security",
  "task": "인증 로직 보안감사",
  "status": "done",
  "files": [".ai-company/security/auth-audit.md"]
}
```

completedPhases에 해당 부서 추가 (최초 완료 시).

---

## 하지 말 것

- dev/qa 작업을 직접 수행하지 않는다 — `/dev`, `/qa` 안내
- 부서 판단 없이 바로 실행하지 않는다 — 잘못된 전문가가 작업하면 품질 저하

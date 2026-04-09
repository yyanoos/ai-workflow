# AI Workflow

AI가 만들고, 테스트가 지킨다.

Claude Code를 활용한 테스트 주도 개발 워크플로우 프레임워크.

## 철학

1. **최소 명령어**: `/gen-api-tests`와 `/dev` 두 개로 전체 워크플로우 커버
2. **AI 생산성에 안정성 부여**: AI가 만든 코드를 TDD + 리뷰로 품질 보장

## 설치

```bash
git clone https://github.com/yyanoos/ai-workflow.git
cd ai-workflow

# Mac/Linux
bash install.sh

# Windows (PowerShell)
./install.ps1
```

`~/.claude/commands/`와 `~/.claude/agents/`에 파일이 복사됩니다.

> 소스를 수정한 뒤에는 install 스크립트를 다시 실행해야 반영됩니다. 세션 재시작은 필요 없습니다 (slash command는 매 호출 시 파일을 새로 읽습니다).

## 두 가지 워크플로우

| 커맨드 | 용도 | 동시 세션 | 언제 사용 |
|--------|------|-----------|----------|
| `/gen-api-tests` | 기존 프로젝트에 테스트 커버리지 구축 | 단일 세션 | AI Workflow 최초 적용 시 |
| `/dev` | TDD 기반 기능 개발/수정/버그 수정 | **복수 세션** (기능별 독립) | 테스트 환경 구축 후 일상 개발 |

---

## /gen-api-tests — 테스트 커버리지 구축

기존 프로젝트에 테스트가 없을 때, 엔드포인트 1개씩 통합 테스트를 만들어간다.

> 단일 세션에서 실행할 것. endpoints.json을 공유 상태로 사용하므로 동시 실행 시 충돌 가능.

### 첫 실행 시 (Phase 0~1)

1. **Phase 0 - 프로젝트 분석**: 프로젝트 구조를 분석하여 아래를 생성
   - `PROJECT_CONTEXT.md` (아키텍처, 도메인, 제약사항)
   - 컨트롤러 메서드에 `[AI-CONTEXT]` 주석 (비자명한 비즈니스 의도)
   - 테스트 인프라 (`docker-compose.test.yml`, 테스트 프로필, 의존성, DB 스키마)
   - **멈춤** — 사람이 의도 검수 (인프라는 에이전트가 동작 검증 완료)

2. **Phase 1 - 엔드포인트 스캔**: 모든 API 엔드포인트를 찾아 `endpoints.json` 생성
   - **멈춤** — 사람이 검수

### 이후 실행 (Phase 2~4, 엔드포인트 1개씩)

3. **Phase 2 - 테스트 생성+실행**: AI가 테스트를 작성하고 직접 실행 (실패 시 자동 수정, 최대 3회)
4. **Phase 3 - AI 리뷰**: 테스트 의도 적합성 검증 (NEEDS_WORK 시 반영+재실행+재리뷰 1회)
   - **멈춤** — 사람이 통과한 테스트의 의도를 최종 검수
5. **Phase 4 - 승인**: 검수 완료 후 재실행하면 done 처리, 다음 엔드포인트로 진행

### 플래그

| 플래그 | 용도 |
|--------|------|
| `POST /api/auth/login` | 특정 엔드포인트 지정 |
| `--reanalyze` | Phase 0 강제 재실행 |
| `--rescan` | Phase 1 강제 재실행 |
| `--retry-failed` | 실패한 엔드포인트를 pending으로 리셋 |

---

## /dev — TDD 기반 개발

기능 개발, 수정, 버그 수정을 TDD 방식으로 수행한다.

**여러 세션에서 동시에 다른 기능을 개발할 수 있다.** 각 기능은 `.dev/{slug}/`에 독립적으로 상태를 관리하고, `feature/{slug}` 브랜치에서 작업한다.

```
/dev "게시판 CRUD API 추가"     # 세션 A
/dev "알림 기능 추가"             # 세션 B (동시 가능)
```

### 흐름

1. **Phase 1 - 구현 명세** [대화형]: 개발자와 대화하여 spec 작성 + 기능 브랜치 생성
   - 변경 유형 파악 (신규/수정/버그) → 영향 범위, 스키마 변경, 수용 기준 합의
   - 산출물: `.dev/{slug}/spec.md`, `feature/{slug}` 브랜치
   - **멈춤** — 사람이 spec 승인

2. **Phase 2 - 테스트 작성**: 구현 명세 기반 통합 테스트 작성 + RED 확인 (컴파일 성공, 테스트 실패)
   - 스키마 변경 있으면 마이그레이션 먼저 생성
   - **멈춤** — 사람이 테스트 의도 검수

3. **Phase 3 - 구현**: 테스트를 통과시키는 프로덕션 코드 작성
   - 제약: 테스트 수정 금지, 기존 코드 리팩토링 금지
   - 완료 조건: 전체 테스트 통과 (새 것 + 기존 것)
   - 막히면 중단 + 사유 보고

4. **Phase 4 - 코드 리뷰**: 빅테크 시니어 관점 리뷰
   - 필수: 보안, 에러 처리 / 주의: 성능, DB 안전성 / 권장: 설계, 유지보수성
   - NEEDS_WORK: minor는 메인이 반영, major는 implementer 재호출
   - **멈춤** — 사람 최종 검수

5. **Phase 5 - MR + 알림**: commit → push → MR 생성 → Slack 알림 (설정 시)

### 플래그

| 플래그 | 용도 |
|--------|------|
| `게시판 CRUD API 추가` | 기능 설명 (새 기능 시작 또는 기존 기능 재진입) |
| `--respec` | Phase 1 강제 재실행 |
| `--retest` | Phase 2 강제 재실행 |
| `--from 3` | 특정 Phase부터 시작 |

### 상태 머신

```
spec → red → green → reviewed → merged
                  → blocked → (사람 판단) → spec 또는 green
```

---

## 구성 파일

```
ai-workflow/
├── commands/
│   ├── gen-api-tests.md       ← 테스트 커버리지 구축
│   └── dev.md                 ← TDD 기반 개발
├── agents/
│   ├── project-analyzer.md    ← 프로젝트 분석 (gen-api-tests Phase 0)
│   ├── endpoint-scanner.md    ← 엔드포인트 스캔 (gen-api-tests Phase 1)
│   ├── test-writer.md         ← 기존 코드 테스트 생성 (gen-api-tests Phase 2)
│   ├── test-reviewer.md       ← 테스트 리뷰 (gen-api-tests Phase 3)
│   ├── spec-test-writer.md    ← 명세 기반 테스트 작성 (dev Phase 2)
│   ├── implementer.md         ← 구현 (dev Phase 3)
│   └── code-reviewer.md       ← 코드 리뷰 (dev Phase 4)
├── install.sh / install.ps1
├── overview.html              ← 워크플로우 시각화 (브라우저에서 열기)
└── README.md
```

## 워크플로우 개요

`overview.html`을 브라우저에서 열면 전체 흐름을 한눈에 볼 수 있습니다.

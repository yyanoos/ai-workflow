# AI Workflow

AI가 만들고, 테스트가 지킨다.

Claude Code를 활용한 테스트 주도 개발 워크플로우 프레임워크.

## 철학

1. **최소 명령어**: 핵심 워크플로우 몇 개로 전체 개발 사이클 커버
2. **AI 생산성에 안정성 부여**: AI가 만든 코드를 TDD + 리뷰로 품질 보장
3. **사람 승인 필수**: 모든 단계에서 사람이 검수 후 다음으로 진행

## 설치

```bash
git clone https://github.com/yyanoos/ai-workflow.git
cd ai-workflow

# Mac/Linux
bash install.sh

# Windows (PowerShell)
./install.ps1
```

`~/.claude/commands/`와 `~/.claude/agents/`에 심링크가 생성됩니다.
(Windows에서 심링크 불가 시 자동으로 복사 방식 폴백)

> 심링크 방식은 소스 수정이 즉시 반영됩니다. 복사 방식은 수정 후 install 재실행이 필요합니다.

### 제거

```bash
# Mac/Linux
bash install.sh --uninstall

# Windows (PowerShell)
./install.ps1 -Uninstall
```

## 커맨드 목록

| 커맨드 | 용도 | 동시 세션 |
|--------|------|-----------|
| `/start` | 프로젝트 시작 — 의도 파악 후 적합한 전문가 라우팅 | - |
| `/who` | 전문가 안내 — 프로젝트 상태에 따른 전문가 목록 + 추천 | - |
| `/dev` | TDD 기반 기능 개발/수정/버그 수정 | **복수** (기능별 독립) |
| `/qa` | QA — 테스트 커버리지 구축, 테스트 전략 | 단일 |
| `/gen-api-tests` | 기존 프로젝트 테스트 커버리지 구축 (/qa의 전신) | 단일 |
| `/evolve` | 자가발전 모드 — 별도 브랜치에서 자율 개선 | 토큰 예산 공유 |
| `/tips` | Claude Code 기능 가이드 | - |
| `/session-docs` | 세션 작업 요약 및 인수인계 문서 생성 | - |

---

## /dev — TDD 기반 개발

기능 개발, 수정, 버그 수정을 TDD 방식으로 수행한다.

**여러 세션에서 동시에 다른 기능을 개발할 수 있다.** 각 기능은 `.ai-company/dev/{slug}/`에 독립적으로 상태를 관리하고, `feature/{slug}` 브랜치에서 작업한다.

```
/dev "게시판 CRUD API 추가"     # 세션 A
/dev "알림 기능 추가"             # 세션 B (동시 가능)
```

### 흐름

1. **Phase 1 - 구현 명세** [대화형]: 개발자와 대화하여 spec 작성 + 기능 브랜치 생성
   - 변경 유형 파악 (신규/수정/버그) → 영향 범위, 스키마 변경, 수용 기준 합의
   - 산출물: `.ai-company/dev/{slug}/spec.md`, `feature/{slug}` 브랜치
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

## /qa — QA 워크플로우

테스트 커버리지 구축과 테스트 전략 수립을 담당한다.

```
/qa                     # 기본: 엔드포인트 1개씩 테스트 구축
/qa strategy            # 테스트 전략 수립
/qa --reanalyze         # 프로젝트 재분석
/qa --rescan            # 엔드포인트 재스캔
/qa --retry-failed      # 실패 엔드포인트 재시도
```

---

## /evolve — 자가발전 모드

별도 브랜치에서 자율적으로 프로젝트를 개선한다. PR + HTML 리포트로 사람에게 제출.

```
/evolve --focus test              # 테스트 커버리지 보강
/evolve --focus security          # 보안 점검
/evolve --focus cleanup           # 데드코드, TODO 정리
/evolve --max-commits 5           # 커밋 수 제한
/evolve --status                  # 진행 상태 확인
```

---

## 에이전트 구성

| 에이전트 | 역할 | 사용처 |
|----------|------|--------|
| `project-analyzer` | 프로젝트 분석, PROJECT_CONTEXT.md 생성 | /qa Phase 0 |
| `endpoint-scanner` | API 엔드포인트 스캔 | /qa Phase 1 |
| `test-writer` | 기존 코드 통합 테스트 생성 | /qa Phase 2 |
| `test-reviewer` | 테스트 품질 리뷰 (major/minor severity) | /qa Phase 3 |
| `spec-test-writer` | 명세 기반 통합 테스트 작성 | /dev Phase 2 |
| `implementer` | 테스트를 통과시키는 구현 | /dev Phase 3 |
| `code-reviewer` | 코드 품질 리뷰 (major/minor severity) | /dev Phase 4 |
| `impact-analyzer` | 변경 전 크로스 영향 분석 | /dev Phase 3 사전 |
| `tip-advisor` | 상황별 기능 추천 (내부 참조) | 각 커맨드 |

---

## 프로젝트 구조

```
ai-workflow/
├── commands/
│   ├── start.md              ← 총괄 오케스트레이터
│   ├── who.md                ← 전문가 안내
│   ├── dev.md                ← TDD 기반 개발
│   ├── qa.md                 ← QA 워크플로우
│   ├── gen-api-tests.md      ← 테스트 커버리지 구축 (레거시)
│   ├── evolve.md             ← 자가발전 모드
│   ├── tips.md               ← Claude Code 기능 가이드
│   └── session-docs.md       ← 세션 문서 생성기
├── agents/
│   ├── project-analyzer.md
│   ├── endpoint-scanner.md
│   ├── test-writer.md
│   ├── test-reviewer.md
│   ├── spec-test-writer.md
│   ├── implementer.md
│   ├── code-reviewer.md
│   ├── impact-analyzer.md
│   └── tip-advisor.md
├── install.sh / install.ps1
├── overview.html             ← 워크플로우 시각화 (브라우저에서 열기)
└── README.md
```

## 트러블슈팅

| 문제 | 해결 |
|------|------|
| BLOCKED (구현 불가) | spec 수정: `/dev --respec`, 직접 해결 후: `/dev --from 3` |
| FAIL (테스트 3회 실패) | `/qa --retry-failed` 후 재시도, 원인 파악: `/investigate` |
| ERROR (인프라 문제) | `docker compose -f docker-compose.test.yml down && up -d --wait` |
| CONFLICT (파일 충돌) | 충돌 세션 완료 대기, 또는 `/dev --list`로 현황 파악 |
| 설치 후 커맨드 미인식 | install 스크립트 재실행, Claude Code 세션 재시작 |
| Windows 심링크 실패 | 개발자 모드 활성화 또는 관리자 권한 실행 (자동 복사 폴백) |

## 워크플로우 개요

`overview.html`을 브라우저에서 열면 전체 흐름을 한눈에 볼 수 있습니다.

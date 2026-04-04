# API 통합 테스트 자동 생성

기존 프로젝트에 테스트 커버리지를 구축한다. 실행할 때마다 미완료 엔드포인트 1개를 처리하고 멈추므로, 사람이 검수한 뒤 다시 실행하면 된다.

인자: $ARGUMENTS (없으면 자동으로 다음 미완료 엔드포인트 처리. 특정 엔드포인트 지정 가능: `POST /api/auth/login`)

---

## 실행 흐름

아래 Phase를 순서대로 확인하며, 해당 Phase의 산출물이 없으면 그 Phase를 실행하고 **멈춘다**.
이미 산출물이 있으면 다음 Phase로 넘어간다.

---

## Phase 0: 프로젝트 분석 (PROJECT_CONTEXT.md 없을 때)

프로젝트 루트에 `PROJECT_CONTEXT.md`가 없으면 실행한다.

### 실행

Explore 서브에이전트를 실행하여 프로젝트 전체를 파악한다. 서브에이전트 프롬프트:

```
이 프로젝트를 분석하여 PROJECT_CONTEXT.md를 작성해주세요.

포함할 내용:
1. 서비스 아키텍처 (모듈 간 관계, 데이터 흐름)
2. 데이터 모델 관계 (주요 엔티티, 관계)
3. 인증/인가 구조
4. 외부 의존성 (DB, 메시지큐, 외부 API 등)
5. API 요약 테이블 — 모든 엔드포인트를 아래 형식으로:
   | Method | Path | 비즈니스 의도 |
   |--------|------|-------------|
   | POST | /api/auth/login | 회원 로그인 후 JWT 발급 |

제약:
- 최대 200줄
- 엔드포인트별 상세 설명은 테이블 1줄로 압축
- 추측하지 말고, 코드에서 확인된 것만 기록
- 한국어로 작성
```

### 산출물
- 프로젝트 루트에 `PROJECT_CONTEXT.md` 생성
- CLAUDE.md에 아래 내용이 없으면 추가:
  ```
  ## 프로젝트 컨텍스트
  매 세션 시작 시 `PROJECT_CONTEXT.md`를 반드시 읽을 것.
  ```

### 여기서 멈춤
사람에게 PROJECT_CONTEXT.md 검수를 요청한다. 내용이 정확한지, 빠진 것이 없는지 확인하라고 안내.

---

## Phase 1: 엔드포인트 스캔 (endpoints.json 없을 때)

`.test-coverage/endpoints.json`이 없으면 실행한다.

### 실행

1. **기술 스택 감지**: 프로젝트 루트의 빌드 파일로 판단
   - `build.gradle` / `pom.xml` → Spring Boot
   - `package.json` → Node.js (Express/Fastify/NestJS 등)
   - `requirements.txt` / `pyproject.toml` → Python (FastAPI/Flask/Django)
   - `go.mod` → Go

2. **엔드포인트 추출**: 컨트롤러/라우트 파일을 모두 읽고 엔드포인트 추출
   - Spring Boot: `@RequestMapping`, `@GetMapping`, `@PostMapping` 등
   - Express/Fastify: `router.get()`, `app.post()` 등
   - FastAPI: `@app.get()`, `@router.post()` 등

3. **PROJECT_CONTEXT.md의 API 요약 테이블**에서 `businessIntent` 매칭

4. **endpoints.json 생성**:
```json
{
  "projectName": "프로젝트명",
  "techStack": "spring-boot | express | fastapi | ...",
  "scannedAt": "ISO 날짜",
  "endpoints": [
    {
      "id": "auth-login",
      "method": "POST",
      "path": "/api/auth/login",
      "controller": "AuthController",
      "controllerFile": "src/main/.../AuthController.java",
      "service": "AuthService",
      "serviceFile": "src/main/.../AuthService.java",
      "authRequired": false,
      "businessIntent": "회원 로그인 후 JWT 발급",
      "status": "pending"
    }
  ]
}
```

5. `.test-coverage/`를 `.gitignore`에 추가 (이미 있으면 스킵)

### 산출물
- `.test-coverage/endpoints.json`
- 스캔 결과 요약 출력 (총 엔드포인트 수, 컨트롤러별 수)

### 여기서 멈춤
사람에게 스캔 결과 검수를 요청한다. 빠진 엔드포인트가 없는지, businessIntent가 맞는지 확인하라고 안내.

---

## Phase 2: 테스트 생성

endpoints.json과 PROJECT_CONTEXT.md가 모두 있으면 이 Phase부터 실행.

### 대상 선택
- `$ARGUMENTS`가 있으면: 매칭되는 엔드포인트 선택
- 없으면: `"status": "pending"` 인 첫 번째 엔드포인트
- 전부 `"done"` 이면: "모든 엔드포인트 테스트 완료!" 출력 후 종료

선택된 엔드포인트를 출력:
```
대상: POST /api/auth/login (AuthController)
의도: 회원 로그인 후 JWT 발급
```

### 사전 조사
1. 컨트롤러 소스 읽기 — 요청/응답 형태, 유효성 검증, 에러 처리
2. 서비스 소스 읽기 (있으면) — 비즈니스 로직, 예외 조건
3. PROJECT_CONTEXT.md 읽기 — 전체 맥락, 해당 API의 비즈니스 의도

### 테스트 파일 위치
기존 테스트 디렉토리 내 `integration/` 서브패키지에 생성한다. 기존 테스트와 분리된 AI 전용 트랙.
- Spring Boot: `src/test/java/{패키지}/integration/`
- Node.js: `tests/integration/` 또는 `__tests__/integration/`
- Python: `tests/integration/`

AI 전용 헬퍼는 `integration/support/`에 배치.
- 기존 프로젝트에 재활용할 만한 헬퍼가 있으면 **복사해서** support/에 가져옴 (import 하지 않음 — 독립 유지)
- 새로 필요한 헬퍼도 여기에 생성

### 테스트 작성 규칙
- **통합 테스트 스타일**: 실제 HTTP 요청을 보내는 것처럼 작성
  - Spring Boot: `@SpringBootTest` + `MockMvc` 또는 `TestRestTemplate`
  - Express/Fastify: `supertest`
  - FastAPI: `TestClient` 또는 `httpx`

- **최소 테스트 케이스**:
  - 성공 케이스 1개
  - 실패 케이스 1개 (잘못된 입력, 인증 실패 등)
  - 인증 필요 엔드포인트: unauthorized 케이스 추가
  - 유효성 검증이 있는 엔드포인트: invalid input 케이스 추가

---

## Phase 3: 서브에이전트 리뷰

테스트 생성 직후 자동 실행. Agent 도구로 서브에이전트를 띄운다.

### 서브에이전트 프롬프트

```
당신은 시니어 QA 엔지니어입니다.
생성된 테스트 코드를 검토하고, 누락된 엣지케이스를 찾아주세요.

[테스트 파일 경로], [컨트롤러 파일 경로], [서비스 파일 경로]를 읽고,
[PROJECT_CONTEXT.md 경로]를 참조하여 비즈니스 맥락을 파악하세요.

검토 체크리스트:
1. 인증/인가 엣지케이스 (토큰 없음, 만료, 권한 부족)
2. 입력 유효성 (null, 빈 값, 경계값, 타입 불일치)
3. 비즈니스 로직 엣지케이스 (중복, 미존재 리소스, 상태 충돌)
4. 에러 응답 형식 일관성
5. 테스트 데이터의 현실성
6. **비즈니스 의도에 맞는 테스트인지** (PROJECT_CONTEXT.md 기반)

아래 형식으로 답하세요:

## 판정: PASS 또는 NEEDS_WORK

## 발견사항 (NEEDS_WORK인 경우)
- 추가할 테스트 케이스 (구체적으로: 테스트명, 입력값, 기대 결과)
- 수정할 기존 테스트 (있으면)
```

### 결과 처리
- **PASS**: Phase 4로 진행
- **NEEDS_WORK**: 서브에이전트가 제안한 내용을 테스트 파일에 자동 반영 후 Phase 4로 진행

---

## Phase 4: 테스트 실행

해당 테스트 파일만 실행한다.

- Spring Boot: `./gradlew test --tests "패키지.클래스명"` 또는 `./mvnw test -Dtest=클래스명`
- Node.js: `npx jest 파일경로` 또는 `npx vitest run 파일경로`
- Python: `pytest 파일경로`

### 결과 처리
- **전부 통과**: endpoints.json 해당 엔드포인트 status → `"done"`
- **실패 있음**: 실패 원인 분석 후 수정, 재실행. 최대 3회 시도.
  - 3회 실패 시: status → `"failed"`, 사람에게 맡김

---

## Phase 5: 결과 보고

처리 결과를 요약 출력:

```
✓ 완료: POST /api/auth/login
  - 테스트 파일: src/test/.../integration/AuthControllerIT.java
  - 테스트 케이스: 4개 (성공1, 실패1, 인증1, 유효성1)
  - 리뷰: PASS (또는 NEEDS_WORK → 2건 자동 반영)
  - 실행: 4/4 통과

진행 현황: 1/45 완료 (2.2%)
다음 대상: GET /api/members (MemberController) — 회원 목록 조회
```

**여기서 멈춘다.** 사람이 생성된 테스트를 검수한 뒤, 다시 `/gen-api-tests`를 실행하면 다음 엔드포인트를 처리한다.

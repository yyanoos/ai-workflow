# AI Workflow

AI가 만들고, 테스트가 지킨다.

Claude Code를 활용한 테스트 주도 개발 워크플로우 프레임워크.

## 설치

```bash
git clone https://github.com/yyanoos/ai-workflow.git
cd ai-workflow

# Mac/Linux
bash install.sh

# Windows (PowerShell)
./install.ps1
```

`~/.claude/commands/`에 slash command가 복사됩니다.

## 사용법

아무 백엔드 프로젝트 디렉토리에서:

```
/gen-api-tests
```

최초 실행 시 프로젝트 분석 → 엔드포인트 스캔을 순차 수행하고,
이후 실행할 때마다 미완료 엔드포인트 1개의 통합 테스트를 생성합니다.

매 실행마다 사람이 검수한 뒤 다시 실행하는 구조입니다.

## 워크플로우 개요

`overview.html`을 브라우저에서 열면 전체 흐름을 한눈에 볼 수 있습니다.

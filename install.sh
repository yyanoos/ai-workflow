#!/bin/bash
# AI Workflow - 설치 스크립트
# ~/.claude/ 에 심링크를 생성합니다.
# 소스 수정 시 즉시 반영되며, 다른 프로젝트에서 수정해도 소스에 반영됩니다.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
CMD_COUNT=0
AGENT_COUNT=0

# --uninstall 옵션
if [[ "${1:-}" == "--uninstall" ]]; then
  echo "AI Workflow 제거 중..."
  for cmd in "$SCRIPT_DIR/commands/"*.md; do
    filename=$(basename "$cmd")
    target="$CLAUDE_DIR/commands/$filename"
    if [[ -L "$target" || -f "$target" ]]; then
      rm -f "$target"
      echo "  제거: $target"
    fi
  done
  for agent in "$SCRIPT_DIR/agents/"*.md; do
    filename=$(basename "$agent")
    target="$CLAUDE_DIR/agents/$filename"
    if [[ -L "$target" || -f "$target" ]]; then
      rm -f "$target"
      echo "  제거: $target"
    fi
  done
  echo ""
  echo "제거 완료."
  exit 0
fi

# Commands 설치 (심링크)
mkdir -p "$CLAUDE_DIR/commands"
for cmd in "$SCRIPT_DIR/commands/"*.md; do
  filename=$(basename "$cmd")
  target="$CLAUDE_DIR/commands/$filename"
  rm -f "$target"
  ln -s "$cmd" "$target"
  echo "  커맨드: /$( echo "$filename" | sed 's/\.md$//' )"
  CMD_COUNT=$((CMD_COUNT + 1))
done

# Agents 설치 (심링크)
mkdir -p "$CLAUDE_DIR/agents"
for agent in "$SCRIPT_DIR/agents/"*.md; do
  filename=$(basename "$agent")
  target="$CLAUDE_DIR/agents/$filename"
  rm -f "$target"
  ln -s "$agent" "$target"
  echo "  에이전트: $( echo "$filename" | sed 's/\.md$//' )"
  AGENT_COUNT=$((AGENT_COUNT + 1))
done

# 검증
INSTALLED_CMDS=$(find "$CLAUDE_DIR/commands" -name "*.md" -type l 2>/dev/null | wc -l | tr -d ' ')
INSTALLED_AGENTS=$(find "$CLAUDE_DIR/agents" -name "*.md" -type l 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo "설치 완료 (심링크 방식 — 소스 수정 시 즉시 반영)"
echo "  커맨드: ${CMD_COUNT}개 설치 (${INSTALLED_CMDS}개 확인)"
echo "  에이전트: ${AGENT_COUNT}개 설치 (${INSTALLED_AGENTS}개 확인)"
echo ""
echo "주요 커맨드:"
echo "  /start  — 프로젝트 시작 (총괄 오케스트레이터)"
echo "  /who    — 전문가 안내"
echo "  /dev    — TDD 기반 개발"
echo "  /qa     — 테스트 커버리지 구축"
echo "  /evolve — 자가발전 모드"
echo "  /tips   — Claude Code 기능 가이드"
echo ""
echo "제거: $0 --uninstall"

#!/bin/bash
# AI Workflow - 설치 스크립트
# ~/.claude/ 에 커맨드와 에이전트를 복사합니다.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

# Commands 설치
mkdir -p "$CLAUDE_DIR/commands"
for cmd in "$SCRIPT_DIR/commands/"*.md; do
  filename=$(basename "$cmd")
  cp "$cmd" "$CLAUDE_DIR/commands/$filename"
  echo "커맨드 설치됨: $CLAUDE_DIR/commands/$filename"
done

# Agents 설치
mkdir -p "$CLAUDE_DIR/agents"
for agent in "$SCRIPT_DIR/agents/"*.md; do
  filename=$(basename "$agent")
  cp "$agent" "$CLAUDE_DIR/agents/$filename"
  echo "에이전트 설치됨: $CLAUDE_DIR/agents/$filename"
done

echo ""
echo "설치 완료. Claude Code에서 /gen-api-tests 로 사용하세요."

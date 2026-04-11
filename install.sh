#!/bin/bash
# AI Workflow - 설치 스크립트
# ~/.claude/ 에 심링크를 생성합니다.
# 소스 수정 시 즉시 반영되며, 다른 프로젝트에서 수정해도 소스에 반영됩니다.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

# Commands 설치 (심링크)
mkdir -p "$CLAUDE_DIR/commands"
for cmd in "$SCRIPT_DIR/commands/"*.md; do
  filename=$(basename "$cmd")
  target="$CLAUDE_DIR/commands/$filename"
  # 기존 파일/심링크 제거 후 새 심링크 생성
  rm -f "$target"
  ln -s "$cmd" "$target"
  echo "커맨드 링크: $target → $cmd"
done

# Agents 설치 (심링크)
mkdir -p "$CLAUDE_DIR/agents"
for agent in "$SCRIPT_DIR/agents/"*.md; do
  filename=$(basename "$agent")
  target="$CLAUDE_DIR/agents/$filename"
  rm -f "$target"
  ln -s "$agent" "$target"
  echo "에이전트 링크: $target → $agent"
done

echo ""
echo "설치 완료 (심링크 방식 — 소스 수정 시 즉시 반영)"
echo "  /start — 프로젝트 시작 (총괄 오케스트레이터)"
echo "  /who   — 전문가 안내"
echo "  /dev   — TDD 기반 개발"
echo "  /qa    — 테스트 커버리지 구축"

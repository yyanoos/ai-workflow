#!/bin/bash
# AI Workflow - 설치 스크립트
# ~/.claude/commands/ 에 커맨드 파일을 복사합니다.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$HOME/.claude/commands"

mkdir -p "$TARGET_DIR"

for cmd in "$SCRIPT_DIR/commands/"*.md; do
  filename=$(basename "$cmd")
  cp "$cmd" "$TARGET_DIR/$filename"
  echo "설치됨: $TARGET_DIR/$filename"
done

echo ""
echo "설치 완료. Claude Code에서 /gen-api-tests 로 사용하세요."

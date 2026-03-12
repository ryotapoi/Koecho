#!/bin/sh
# claude-fmt.sh — Claude Code で音声書き起こしを整形するスクリプト
#
# 使い方:
#   Koecho のスクリプト設定に登録:
#     ./examples/claude-fmt.sh          # デフォルト（整形）
#     ./examples/claude-fmt.sh e        # 英訳プリセット
#
# 前提:
#   - Claude Code (claude) が PATH に入っていること
#   - プリセットファイルを ~/.config/claude-textfmt/ に配置すること
#     (examples/claude-textfmt/ にサンプルあり)

set -eu

RULES_DIR="${HOME}/.config/claude-textfmt"
preset="${1:-default}"
RULES_FILE="${RULES_DIR}/${preset}.md"

if [ ! -f "$RULES_FILE" ]; then
  echo "rules not found: $RULES_FILE" >&2
  exit 1
fi

input="$(cat)"

# 空入力はそのまま返す
if [ -z "$input" ] || [ -z "$(echo "$input" | tr -d '[:space:]')" ]; then
  printf "%s" "$input"
  exit 0
fi

payload="$(printf '<transcript>%s</transcript>' "$input")"

printf "%s" "$payload" | \
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
  CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1 \
  DISABLE_NON_ESSENTIAL_MODEL_CALLS=1 \
  MAX_THINKING_TOKENS=0 \
  claude -p \
    --system-prompt-file "$RULES_FILE" \
    --tools "" \
    --disable-slash-commands \
    --no-session-persistence \
    --strict-mcp-config --mcp-config '{"mcpServers":{}}' \
    --max-turns 1 \
    --output-format text \
    --model haiku

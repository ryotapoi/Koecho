#!/bin/sh
# echo-env.sh — Koecho 環境変数の確認用スクリプト
#
# Koecho がスクリプトに渡す入力と環境変数を表示します。
# 設定画面でこのスクリプトを登録し、動作確認に使ってください。

input="$(cat)"

echo "=== Input (stdin) ==="
echo "$input"
echo ""
echo "=== Environment ==="
echo "KOECHO_SELECTION: ${KOECHO_SELECTION:-(empty)}"
echo "KOECHO_SELECTION_START: ${KOECHO_SELECTION_START:-(empty)}"
echo "KOECHO_SELECTION_END: ${KOECHO_SELECTION_END:-(empty)}"
echo "KOECHO_PROMPT: ${KOECHO_PROMPT:-(empty)}"

#!/bin/sh
# Before first use, run `sudo fm license` manually to accept Apple's license.

set -eu

input_file=$(mktemp "${TMPDIR:-/tmp}/koecho-fm-textfmt.XXXXXX")
trap 'rm -f "$input_file"' EXIT
script_dir=$(CDPATH= cd -P "$(dirname "$0")" && pwd)
cat > "$input_file"

if ! grep -q '[^[:space:]]' "$input_file"; then
  cat "$input_file"
  exit 0
fi

instructions=$(cat "$script_dir/fm-textfmt-prompt.md")

{
  printf '<transcript>'
  cat "$input_file"
  printf '</transcript>'
} | /usr/bin/fm respond --no-stream --instructions "$instructions"

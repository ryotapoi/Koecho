#!/bin/zsh
# Before first use, run `sudo fm license` manually to accept Apple's license.

set -euo pipefail

script_dir=$(CDPATH= cd -P "$(dirname "$0")" && pwd)
rules_file="$script_dir/fm-textfmt-prompt.md"
schema_file="$script_dir/fm-textfmt.schema.json"

# Sentinel preserves trailing newlines while reading stdin.
input="$(cat; printf '\036')"
input="${input%$'\036'}"

if [[ -z "$input" ]] || [[ -z "${input//[[:space:]]/}" ]]; then
  printf "%s" "$input"
  exit 0
fi

printf "%s" "$input" |
  /usr/bin/python3 -c 'import json, sys; sys.stdout.write(json.dumps({"transcript": sys.stdin.read()}, ensure_ascii=False))' |
  /usr/bin/fm respond --no-stream --greedy --instructions "$(cat "$rules_file")" --schema "$schema_file" |
  /usr/bin/python3 -c 'import json, sys; value = json.load(sys.stdin)["corrected_text"]; assert isinstance(value, str); sys.stdout.write(value)'

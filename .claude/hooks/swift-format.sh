#!/bin/bash
# PostToolUse hook: auto-format Swift files after Write/Edit

FILE_PATH=$(jq -r '.tool_input.file_path' < /dev/stdin)

# Swift files only
if [[ "$FILE_PATH" != *.swift ]]; then
  exit 0
fi

# File must exist (might have been deleted)
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

xcrun swift-format --in-place "$FILE_PATH" 2>&1
exit 0

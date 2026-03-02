# ADR 0006: Script path as shell command string

## Status

Accepted

## Context

Users configure scripts in Koecho's settings by entering a value in the
"Script Path" field. The original implementation treated this value as a
file path: it checked `FileManager.fileExists(atPath:)` and passed it to
`/bin/sh -c "exec \"$0\""` as a positional argument.

This approach failed when users entered arguments alongside the path
(e.g. `/path/to/script.sh arg1 arg2`) because:

1. `fileExists` treated the entire string (path + arguments) as a file path.
2. `exec "$0"` interpreted the full string as the executable name.

Bug B2 tracked this issue.

## Considered Options

- **Option A: Parse the string into path and arguments** — Split on the
  first unquoted space, validate the path portion with `fileExists`, and
  pass the rest as arguments. Complex to implement correctly (quoting,
  escaping) and still limited (no pipes, redirects, or shell features).

- **Option B: Pass the string directly to `/bin/sh -c`** — Treat the
  entire field as a shell command string. Remove `fileExists` validation
  and the `exec "$0"` wrapper. Simple, flexible, and consistent with how
  the spec already describes execution (`/bin/sh -c`).

- **Option C: Separate UI fields for path and arguments** — Add a
  dedicated arguments field. More explicit but adds UI complexity and
  still cannot support pipes or redirects without a shell.

## Decision

We will pass the `scriptPath` value directly to `/bin/sh -c` as a shell
command string (Option B). The `fileExists` check is removed and replaced
with an empty-string validation. The file chooser wraps selected paths in
single quotes to handle spaces.

## Consequences

- Users can now use arguments, pipes, redirects, and other shell features
  directly in the script command field.
- The `fileExists` pre-flight check is gone; a non-existent script now
  produces a shell error (exit code 127) instead of a dedicated
  `scriptNotFound` error.
- The field semantics change from "file path" to "shell command string".
  Existing users with space-containing paths (without quotes) may need to
  add quotes after updating.
- `scriptPath` must only contain user-configured values. Passing untrusted
  input would be a shell injection risk.

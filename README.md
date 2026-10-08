# Koecho

[日本語](README.ja.md) · [Changelog](CHANGELOG.md) · [変更履歴（日本語）](CHANGELOG.ja.md)

A lightweight voice input app for macOS.
Invoke with a hotkey, edit text by voice and keyboard, process it with shell scripts, and paste it into the foreground app.

<img src="derived/screenshot.png" alt="Koecho floating panel" width="600">

## Features

- Voice + keyboard: dictate and edit with the keyboard at the same time. Recognition results update in real time
- On-device speech recognition with spoken punctuation and line breaks
- Built-in text operations: increase or decrease indentation and add block quotes to selected lines without configuring external scripts
- Script integration: transform text with shell scripts, including the Apple Foundation Models voice formatting example

## Requirements

- macOS 27.0 or later

## Installation

### From GitHub Releases

1. Download the latest zip from [Releases](https://github.com/ryotapoi/Koecho/releases)
2. Unzip and move `Koecho.app` to `/Applications`
3. Open `Koecho.app`. Release artifacts are signed with Apple Developer ID and notarized by Apple.

### Build from source

```bash
git clone https://github.com/ryotapoi/Koecho.git
cd Koecho
open Koecho.xcodeproj
```

Build with Xcode.

## Permissions

The system will prompt for these permissions on first launch:

- Accessibility: required for pasting text and reading selected text from the foreground app
- Input Monitoring: required for detecting global hotkeys
- Microphone: required for on-device speech recognition

## Usage

### Basic flow

1. Press the hotkey (default: Fn key) to show the floating panel
2. Dictate or type your text
3. Optionally run a script (the text is replaced in place)
4. Press the hotkey again to confirm and paste into the foreground app
5. Press Escape to cancel

### Script integration

See the [script interface](docs/script-interface.md) for the full input, output, environment, and cancellation contract.

Register shell scripts in the settings. Scripts run via `/bin/sh -c`, receive the full text on stdin, and return the processed result on stdout.

For manual execution, context is also passed via environment variables:

| Variable | Description |
|----------|-------------|
| `KOECHO_SELECTION` | Current selection in the input panel; empty when nothing is selected |
| `KOECHO_PROMPT` | Additional input provided when running the script |
| `KOECHO_SELECTION_START` | Selection start as a UTF-16 code unit offset from the start of the panel text (0-based) |
| `KOECHO_SELECTION_END` | Selection end as a UTF-16 code unit offset in the same text (exclusive) |

With no selection, START and END both equal the caret position. When text selected in an external app can be read, it is imported as the panel text and the caret is placed at the end. Running a script immediately leaves `KOECHO_SELECTION` empty; select the imported text again in the panel to pass it as the selection.

For example, selecting `b` in `😀abc` gives `KOECHO_SELECTION=b`, START=3, and END=4 because `😀` takes two UTF-16 code units. Python `str` indices count Unicode code points, so these offsets cannot be used directly to slice a Python string.

For auto-run on confirm, all three selection variables are empty strings.

Use `examples/echo-env.sh` to verify. Register and run it to see stdin contents and environment variable values.

### Voice transcription correction with Apple Foundation Models

`examples/fm-textfmt.sh` corrects speech recognition mistakes with macOS 27's `/usr/bin/fm`. It reads text from stdin and writes the corrected text to stdout.

```bash
printf '%s\n' '来週の会議は木用日です。' | examples/fm-textfmt.sh
```

Edit `examples/fm-textfmt-prompt.md` to customize the correction instructions. The output format is defined in `examples/fm-textfmt.schema.json`. See the script's opening comment for the first-use license step.

## License

[MIT License](LICENSE)

# Koecho

[日本語](README.ja.md)

A lightweight voice input app for macOS.
Invoke with a hotkey, edit text by voice and keyboard, process it with shell scripts, and paste it into the foreground app.

<img src="derived/screenshot-panel.png" alt="Koecho floating panel" width="600">

## Features

- Voice + keyboard: dictate and edit with the keyboard at the same time. Recognition results update in real time
- Built on macOS Dictation: no extra speech engine required. Punctuation and line breaks can be spoken (macOS 26+ also supports the Speech framework engine)
- Script integration: transform text with shell scripts. Combine with Claude Code headless mode to auto-format or translate voice transcriptions

## Requirements

- macOS 14.0 (Sonoma) or later
- SpeechAnalyzer engine requires macOS 26 or later

## Installation

### From GitHub Releases

1. Download the latest zip from [Releases](https://github.com/ryotapoi/Koecho/releases)
2. Unzip and move `Koecho.app` to `/Applications`
3. On first launch, macOS will warn that the developer cannot be verified (the app is not signed with an Apple Developer ID)
   - Right-click Koecho.app and select "Open"
   - Click "Open" in the confirmation dialog
   - Subsequent launches will work normally

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
- Microphone (when using SpeechAnalyzer): required for on-device speech recognition

## Usage

### Basic flow

1. Press the hotkey (default: Fn key) to show the floating panel
2. Dictate or type your text
3. Optionally run a script (the text is replaced in place)
4. Press the hotkey again to confirm and paste into the foreground app
5. Press Escape to cancel

### Script integration

Register shell scripts in the settings. Scripts run via `/bin/sh -c`, receive the full text on stdin, and return the processed result on stdout.

Context is also passed via environment variables:

| Variable | Description |
|----------|-------------|
| `KOECHO_SELECTION` | Selected text in the foreground app |
| `KOECHO_PROMPT` | Additional input provided when running the script |
| `KOECHO_SELECTION_START` | Start position of the selection |
| `KOECHO_SELECTION_END` | End position of the selection |

Use `examples/echo-env.sh` to verify. Register and run it to see stdin contents and environment variable values.

### Voice text formatting with Claude Code

`examples/claude-fmt.sh` formats voice transcriptions using Claude Code headless mode (`claude -p`). It uses the Haiku model for speed, with prompts tuned for stable results.

```bash
# Default (Japanese formatting)
examples/claude-fmt.sh

# English translation preset
examples/claude-fmt.sh e
```

Copy preset files from `examples/claude-textfmt/*.md` to `~/.config/claude-textfmt/`. Add presets to switch between different processing patterns.

## License

[MIT License](LICENSE)

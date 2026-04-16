# VoiceInline

A lightweight macOS menu bar app that records your voice via global hotkeys and pastes the result at your cursor position. Supports three modes: speech-to-text, translation to English, and Q&A with an LLM.

## Requirements

- macOS 13 (Ventura) or later
- Xcode Command Line Tools (`xcode-select --install`)
- An OpenAI API key (required)
- An Anthropic API key (optional, for Claude-based Q&A)

## Setup

### 1. Set API Keys

```bash
export OPENAI_API_KEY="sk-..."
export ANTHROPIC_API_KEY="sk-ant-..."   # optional; if unset, Q&A uses OpenAI GPT
```

### 2. Build & Run

```bash
swift build && .build/debug/VoiceInline
```

### 3. Grant Permissions

On first launch the app will:

- **Prompt for Accessibility access** — required for global hotkeys and simulating Cmd+V. Go to *System Settings → Privacy & Security → Accessibility* and enable the app.
- **Prompt for Microphone access** — required for recording audio.

Check the console output for permission status messages.

## Usage

Hold a hotkey combination to record, release to process and paste:

| Hotkey | Mode | Description |
|---|---|---|
| `Ctrl + Shift + 1` | Speech to Text | Transcribes your speech and pastes the text |
| `Ctrl + Shift + 2` | Translate | Transcribes + translates to English, then pastes |
| `Ctrl + Shift + 3` | Q&A | Transcribes your question, sends to LLM, pastes the answer |

The menu bar icon reflects the current state:

- 🎙 — Idle
- 🔴 — Recording
- ⏳ — Processing

Errors are shown as macOS notifications (never pasted into your text).

## Project Structure

```
Sources/
├── main.swift              # App entry point
├── AppDelegate.swift       # Menu bar UI + orchestration
├── HotkeyManager.swift     # Global key event monitoring
├── AudioRecorder.swift     # AVAudioEngine-based mic recording
├── WhisperAPI.swift        # OpenAI Whisper transcription/translation
├── LLMAPI.swift            # GPT / Claude chat completion
├── TextInserter.swift      # Clipboard write + Cmd+V simulation
├── PermissionChecker.swift # Startup permission checks
└── Errors.swift            # Error type definitions
```

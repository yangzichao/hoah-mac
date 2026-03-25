<div align="center">
  <img src="HoAh/Assets.xcassets/AppIcon.appiconset/256-mac.png" width="180" height="180" />
  <h1>HoAh (吼蛙)</h1>
  <p>Local-first macOS dictation with optional cloud transcription and AI post-processing.</p>

  [![License](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
  ![Platform](https://img.shields.io/badge/platform-macOS%2014.0%2B-brightgreen)
</div>

[简体中文](README.md) | **English** | [Website](https://hoah.app/)

---

## Overview

**HoAh** is a macOS dictation app built around a fast capture workflow:
1. Record audio with a keyboard-driven recorder.
2. Transcribe with a selectable speech-to-text backend.
3. Optionally run an **AI Action** step to clean, polish, translate, or answer based on the transcript.

The current codebase is no longer just "local Whisper + optional prompt." It now supports local models, hosted APIs, realtime streaming providers, profile-based AI post-processing, history/export tooling, and data-retention controls.

## What The Current Codebase Includes

- **Recorder-first UX**: Mini recorder and notch recorder modes, configurable hotkeys, push-to-talk/toggle workflow, optional middle-click trigger, menu bar mode, and App Shortcuts support.
- **Multiple transcription backends**: Local `whisper.cpp` models, cloud transcription providers, realtime streaming providers, custom OpenAI-compatible endpoints, and an experimental Apple Speech path.
- **AI Action modes**: Built-in clean, polish, Q&A, and translation flows, including a second translation target and Polish-mode toggles for Formal Writing and Professional/High-EQ output.
- **Custom prompt system**: Add your own prompts and optional trigger words instead of being locked to fixed modes.
- **History and export**: SwiftData-backed transcript history with search/filtering, audio playback, re-transcription from saved audio, CSV export, daily Markdown export, and optional automatic daily-log append.
- **Privacy controls**: Local-first operation, Keychain-backed secrets, transcript/audio cleanup controls, clipboard behavior settings, and security-scoped export-folder access.

## Transcription Backends

- **Local models**: `ggml-base`, `ggml-large-v3`, `ggml-large-v3-turbo`, `ggml-large-v3-turbo-q5_0`
- **Cloud transcription**: Groq Whisper Large v3 Turbo, OpenAI GPT-4o Transcribe, ElevenLabs Scribe v2
- **Realtime streaming**: OpenAI Realtime transcription, ElevenLabs Realtime transcription, Amazon Transcribe Streaming
- **Custom endpoints**: user-defined OpenAI-compatible transcription services
- **Native Apple path**: Apple Speech support exists in the codebase, but it is gated behind future macOS 26+ Speech APIs and build flags

## AI Action Providers

- OpenAI
- Gemini
- Anthropic
- Groq
- Cerebras
- OpenRouter
- AWS Bedrock
- Ollama (local)
- Doubao / Ark-compatible configuration for Chinese UI

These are managed as saved configurations rather than a single global provider toggle. API keys and secrets are stored in Keychain.

## Privacy And Data Handling

- You can use HoAh fully locally if you stick to local transcription and local AI backends.
- Network traffic only happens for the providers you explicitly configure.
- Transcript history is stored locally with SwiftData.
- Saved audio files can be cleaned up independently from transcript records.
- Transcript auto-cleanup supports short retention windows, including aggressive cleanup modes.
- Auto-export uses a user-selected folder with security-scoped bookmarks.

## Requirements

- macOS 14.0 or later
- Xcode with current Apple SDKs is recommended for development
- Local transcription builds require the `whisper.cpp` XCFramework; the repo Makefile can prepare it

## Build From Source

```bash
make all
make dev
```

## Repo Docs

- [App Store release guide](docs/release/APP_STORE_RELEASE.md)
- [Release notes](RELEASE_NOTES.md)

## License

This project is licensed under the GNU General Public License v3.0 – see [LICENSE](LICENSE).

## Acknowledgments

- Core tech: [whisper.cpp](https://github.com/ggerganov/whisper.cpp)
- Core packages currently wired into the project: [Sparkle](https://github.com/sparkle-project/Sparkle), [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts), [LaunchAtLogin-Modern](https://github.com/sindresorhus/LaunchAtLogin-Modern), [mediaremote-adapter](https://github.com/ejbills/mediaremote-adapter), [Zip](https://github.com/marmelroy/Zip), [Swift Atomics](https://github.com/apple/swift-atomics)

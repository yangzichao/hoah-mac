<div align="center">
  <img src="HoAh/Assets.xcassets/AppIcon.appiconset/256-mac.png" width="180" height="180" />
  <h1>HoAh (吼蛙)</h1>
  <p>Recorder-first macOS dictation with optional cloud transcription and AI Actions.</p>

  [![License](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
  ![Platform](https://img.shields.io/badge/platform-macOS%2014.0%2B%20build%20%7C%20macOS%2026%2B%20recommended-brightgreen)
</div>

[简体中文](README.md) | **English** | [Website](https://hoah.app/)

---

## Overview

**HoAh** is a macOS dictation app built around a fast capture workflow:
1. Record audio with a keyboard-driven recorder.
2. Transcribe with a selectable speech-to-text backend.
3. Optionally run an **AI Action** step to clean, polish, translate, or answer based on the transcript.

The current codebase includes local `whisper.cpp` models, hosted transcription APIs, realtime streaming providers, configurable AI Action providers, history/export tooling, and data-retention controls.

## Practical Reality

- The Xcode project still targets **macOS 14.0+**, but the current app is much more realistic to use on **macOS 26+** if you want the project in its present shape to feel normal day to day.
- The Apple Speech path is built around newer macOS 26 APIs and build flags. Older supported macOS versions may still build or launch, but they are not the main reality this codebase is optimized around.
- Local models are not lightweight. `ggml-base` is the easiest local option; the `large-v3` family is much heavier and expects a strong Mac, ideally Apple Silicon with plenty of unified memory.
- If your Mac is lower-end, the practical path is usually smaller local models or cloud transcription instead of the largest local models.

## What The Current Codebase Includes

- **Recorder-first UX**: Mini recorder and notch recorder modes, configurable hotkeys, hold-to-talk / toggle workflows, optional middle-click trigger, menu bar mode, and App Shortcuts support.
- **Multiple transcription backends**: Local `whisper.cpp` models, cloud transcription providers, realtime streaming providers, custom OpenAI-compatible transcription endpoints, and a gated Apple Speech path.
- **AI Actions**: Built-in clean, polish, Q&A, and translation flows, including a second translation target and Polish-mode toggles such as Formal Writing and Professional / High-EQ.
- **Custom prompts**: Add your own prompts and optional trigger words instead of being locked to fixed modes.
- **History and export**: SwiftData-backed transcript history, search/filtering, audio playback, re-transcription from saved audio, CSV export, daily Markdown export, and optional automatic daily-log append.
- **Retention and privacy controls**: Keychain-backed secrets, transcript/audio cleanup controls, clipboard behavior settings, and security-scoped export-folder access.

## Transcription Backends

- **Local models**: `ggml-base`, `ggml-large-v3`, `ggml-large-v3-turbo`, `ggml-large-v3-turbo-q5_0`
- **Cloud transcription**: Groq Whisper Large v3 Turbo, OpenAI GPT-4o Transcribe, ElevenLabs Scribe v2 Batch
- **Realtime streaming**: OpenAI realtime transcription, ElevenLabs realtime transcription, Amazon Transcribe Streaming
- **Custom endpoints**: user-defined OpenAI-compatible transcription services
- **Apple Speech**: present in the codebase, but effectively gated behind macOS 26 APIs and build settings

## AI Action Providers

- OpenAI
- Azure OpenAI
- Gemini
- Anthropic
- GROQ
- Cerebras
- OpenRouter
- AWS Bedrock
- OCI Generative AI
- Ollama (local)
- Doubao / Ark-compatible configuration for Chinese UI

These are managed as saved configurations rather than a single global provider toggle. Secrets are stored in Keychain.

## Privacy And Networking

- Transcript history is stored locally with SwiftData.
- API keys and similar secrets are stored in Keychain.
- If you stay on local transcription plus local AI backends such as Ollama, you can avoid sending transcript content to third-party model providers.
- If you use cloud transcription or cloud AI Action providers, the relevant audio/text will be sent to those providers.
- Non-App-Store builds may still perform Sparkle update checks, so it is not strictly accurate to describe the app as "no network unless you configure a provider."
- Auto-export uses a user-selected folder with security-scoped bookmarks.

## Requirements

- Deployment target: **macOS 14.0 or later**
- Recommended everyday-use OS: **macOS 26 or later**
- Apple Silicon is strongly recommended for local-model usage
- Xcode with current Apple SDKs is recommended for development
- `whisper.cpp` XCFramework is required for source builds because the app links it directly

## Build From Source

1. Prepare `whisper.cpp`:

```bash
make setup
```

2. Configure code signing for your machine. The provided Make targets assume a valid development team:

```bash
DEV_TEAM=YOUR_TEAM_ID make build-debug
make run-debug
```

3. Maintainer-oriented shortcuts such as `make all` and `make dev` also assume your signing setup already works.

## Repo Docs

- [App Store release guide](docs/release/APP_STORE_RELEASE.md)
- [AI release instructions](docs/release/AI_RELEASE_INSTRUCTIONS.md)
- [Release notes](RELEASE_NOTES.md)

## License

This project is licensed under the GNU General Public License v3.0. See [LICENSE](LICENSE).

## Acknowledgments

- Core tech: [whisper.cpp](https://github.com/ggerganov/whisper.cpp)
- Core packages currently wired into the project: [Sparkle](https://github.com/sparkle-project/Sparkle), [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts), [LaunchAtLogin-Modern](https://github.com/sindresorhus/LaunchAtLogin-Modern), [mediaremote-adapter](https://github.com/ejbills/mediaremote-adapter), [Zip](https://github.com/marmelroy/Zip), [Swift Atomics](https://github.com/apple/swift-atomics)

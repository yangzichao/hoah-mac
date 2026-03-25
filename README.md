<div align="center">
  <img src="HoAh/Assets.xcassets/AppIcon.appiconset/256-mac.png" width="180" height="180" />
  <h1>HoAh (吼蛙)</h1>
  <p>Local-first macOS dictation with optional cloud transcription and AI post-processing.</p>
  <p>本地优先的 macOS 听写应用，支持可选的云端转录与 AI 后处理。</p>

  [![License](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
  ![Platform](https://img.shields.io/badge/platform-macOS%2014.0%2B-brightgreen)
</div>

**English | [简体中文](#中文)** · [Website / 项目主页](https://hoah.app/)

---

<details open id="english">
<summary><strong>English</strong></summary>

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

### Requirements
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

### License
Licensed under GNU GPL v3.0 – see [LICENSE](LICENSE).

### Acknowledgments
- Core tech: [whisper.cpp](https://github.com/ggerganov/whisper.cpp)
- Core packages currently wired into the project: [Sparkle](https://github.com/sparkle-project/Sparkle), [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts), [LaunchAtLogin-Modern](https://github.com/sindresorhus/LaunchAtLogin-Modern), [mediaremote-adapter](https://github.com/ejbills/mediaremote-adapter), [Zip](https://github.com/marmelroy/Zip), [Swift Atomics](https://github.com/apple/swift-atomics)

</details>

<details id="中文">
<summary><strong>简体中文</strong></summary>

## 概览

**HoAh** 是一款围绕“快速采集”设计的 macOS 听写应用：
1. 用键盘驱动的录音器采集语音。
2. 使用可切换的语音转文字后端完成转录。
3. 按需进入 **AI Action** 阶段，对转录结果做清洗、润色、翻译或问答。

现在的代码库已经不再只是“本地 Whisper + 可选 Prompt”。它已经包含本地模型、托管 API、实时流式转录、基于配置档的 AI 后处理、历史/导出工具，以及更完整的数据保留控制。

## 当前代码库已经包含的能力

- **录音器优先的交互**：支持 Mini Recorder 和 Notch Recorder，两种录音器形态；可配置快捷键、按住说话/点按切换、可选中键触发、菜单栏模式，以及 App Shortcuts。
- **多种转录后端**：支持本地 `whisper.cpp` 模型、云端转录服务、实时流式转录服务、自定义 OpenAI 兼容接口，以及实验性的 Apple Speech 路径。
- **AI Action 模式**：内置 clean、polish、Q&A、translation 等模式，并支持第二翻译目标；Polish 还可叠加 Formal Writing 和 Professional / High-EQ 两个开关。
- **自定义 Prompt 系统**：除了内置模式，还可以新增自定义 Prompt，并配置 trigger words。
- **历史与导出**：基于 SwiftData 的历史记录、搜索和筛选、音频回放、基于已保存音频的重新转录、CSV 导出、按天 Markdown 导出，以及可选的自动日记追加。
- **隐私与保留控制**：本地优先运行、Keychain 存储密钥、转录/音频清理策略、剪贴板行为控制，以及基于 security-scoped bookmark 的导出目录访问。

## 转录后端

- **本地模型**：`ggml-base`、`ggml-large-v3`、`ggml-large-v3-turbo`、`ggml-large-v3-turbo-q5_0`
- **云端转录**：Groq Whisper Large v3 Turbo、OpenAI GPT-4o Transcribe、ElevenLabs Scribe v2
- **实时流式转录**：OpenAI Realtime transcription、ElevenLabs Realtime transcription、Amazon Transcribe Streaming
- **自定义接口**：用户自定义的 OpenAI 兼容转录服务
- **Apple 原生路径**：代码中已预留 Apple Speech 支持，但依赖未来的 macOS 26+ Speech API 和编译开关，目前属于受限能力

## AI Action 提供商

- OpenAI
- Gemini
- Anthropic
- Groq
- Cerebras
- OpenRouter
- AWS Bedrock
- Ollama（本地）
- 豆包 / Ark 兼容配置（中文界面可用）

这些能力通过“配置档”来管理，而不是一个简单的全局 provider 开关。API Key 和密钥类信息存储在 Keychain 中。

## 隐私与数据处理

- 如果只使用本地转录和本地 AI 后端，HoAh 可以做到完全本地运行。
- 只有在你显式配置并启用云端 provider 时，才会发生网络请求。
- 转录历史通过 SwiftData 保存在本地。
- 音频文件可以独立于文字记录进行清理。
- 转录记录支持更激进的自动清理策略和短保留周期。
- 自动导出使用用户手动选择的文件夹，并通过 security-scoped bookmark 保持访问权限。

### 系统要求
- macOS 14.0 或更高版本
- 开发建议使用较新的 Xcode 与 Apple SDK
- 如果要启用本地转录，仍需要 `whisper.cpp` XCFramework；仓库内的 Makefile 可以辅助完成这部分准备

## 从源码构建

```bash
make all
make dev
```

## 仓库文档

- [App Store 发布说明](docs/release/APP_STORE_RELEASE.md)
- [发布记录](RELEASE_NOTES.md)

### 许可证
本项目采用 GNU General Public License v3.0 – 详见 [LICENSE](LICENSE)。

### 致谢
- 核心技术：[whisper.cpp](https://github.com/ggerganov/whisper.cpp)
- 当前项目中已接入的核心包包括：[Sparkle](https://github.com/sparkle-project/Sparkle), [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts), [LaunchAtLogin-Modern](https://github.com/sindresorhus/LaunchAtLogin-Modern), [mediaremote-adapter](https://github.com/ejbills/mediaremote-adapter), [Zip](https://github.com/marmelroy/Zip), [Swift Atomics](https://github.com/apple/swift-atomics)

</details>

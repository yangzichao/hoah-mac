# HoAh Dictation v3.7.5

### Improvements
* **Right Option AutoSend**: AutoSend now uses a dedicated double-press of the right Option key, so the gesture stays consistent even if you customize the main recording shortcut.
* **Append Shortcut Return**: Restored Append as an optional separate recording shortcut and now write the appended result back to the clipboard while showing the combined text in history.
* **Trigger Copy Cleanup**: Updated recorder badges, settings copy, and localizations so AutoSend and Append are described more clearly throughout the app.

---

# HoAh Dictation v3.7.4

### Improvements
* **Per-Slot Shortcut Controls**: Added individual enable toggles for Selection Action shortcut slots so you can keep only the mappings you want active.
* **Shortcut Editor Refresh**: Reworked the Selection Action shortcut editor into a denser card layout with clearer enabled and disabled status.
* **Shortcut Summary Accuracy**: Updated keyboard shortcut summaries and related localizations so they reflect the currently active Selection Action slots more clearly.

---

# HoAh Dictation v3.7.3

### Improvements
* **Dynamic Selection Action Shortcuts**: Selection Action shortcuts now scale automatically with your active AI Actions, so the shortcut range matches the actions you can actually run.
* **Shortcut Visibility**: Updated the keyboard shortcuts reference and settings UI to show the active Selection Action shortcut range more clearly.
* **Copy & Localization Cleanup**: Refined AI Action shortcut descriptions and localizations for clearer settings guidance.

---

# HoAh Dictation v3.7.2

### Improvements
* **Selection AI Actions**: Updated AI actions to automatically copy the current selection before processing, and renamed the feature from "Clipboard AI Action" to "Selection AI Action" for clarity.
* **Notification & Paste Flow**: Improved Selection AI Action notifications so long-running progress remains visible until the awaited paste completes, then dismisses cleanly.
* **Stability & Motion Tuning**: Fixed settings migration and stale AI runtime error state issues, while refining recorder visualizer motion controls for smoother behavior.

---

# HoAh Dictation v3.7.1

### Improvements
* **Clipboard Action UI**: Added a collapsible configuration section so the Clipboard Action card stays compact until you need the detailed shortcut editor.
* **Whisper Shutdown Safety**: Improved app termination handling to reduce crashes while local Whisper warmup or Metal-backed model resources are still winding down.
* **Theme Selection Cleanup**: Removed unsupported theme options from the UI and aligned the default theme behavior on appearance.

---

# HoAh Dictation v3.7.0

### New Features
* **Azure OpenAI Support**: Added Azure OpenAI as an AI enhancement provider with deployment-aware configuration and endpoint normalization.
* **OCI Generative AI Support**: Added Oracle Cloud Infrastructure Generative AI support with region-aware setup and OpenAI-compatible chat completions.

### Improvements
* **Provider Setup Guidance**: Expanded provider validation, endpoint help text, API key links, and OCI region options to make new AI configurations easier to verify.
* **Recording & Shortcut Reliability**: Refined system audio muting during recording and improved clipboard AI action shortcut change handling.

---

# HoAh Dictation v3.6.9

### Fixes
* **Stability**: Bug fixes and stability improvements.

---

# HoAh Dictation v3.6.8

### Improvements
* **AI Providers Refresh**: Updated Gemini, OpenAI, OpenRouter, GROQ, and Cerebras model recommendations to match current APIs and remove outdated defaults.
* **Faster AI Defaults**: Reordered provider defaults to prefer lower-latency models for everyday polish, translate, and Q&A actions.
* **Model Discovery & Validation**: Improved provider error parsing and added live model discovery for OpenRouter and Cerebras so users see models their API key can actually access.

---

# HoAh Dictation v3.6.7

### Fixes
* **Onboarding Model Downloads**: Fixed the onboarding model download flow so clicking another model during an active download no longer causes stuck downloads or broken UI state.
* **Download Progress State**: Improved onboarding download state handling so progress indicators and action buttons stay in sync.

---

# HoAh Dictation v3.6.1

### Fixes
* **Stability**: Bug fixes and stability improvements.

---

# HoAh Dictation v3.6.0

### Fixes
* **Stability**: Bug fixes and stability improvements.

---

# HoAh Dictation v3.5.8

### Enhancements
* **AI Action Reorder**: Updated the default order of AI Actions to: Basic, Polish, Q&A, Translate. This prioritizes the most commonly used actions.
* **UI Fixes**: 
  - Fixed an issue where the App Icon was displayed at a smaller size on macOS versions prior to Sequoia.
  - Improved the visual consistency of the "AI Action" checkbox in the enhancement menu by ensuring it uses the correct toggle style.

---

# HoAh Dictation v3.5.7

### Fixes
* **Recording Stability**: Fixed a potential crash when exporting audio to WAV.
* **Device Change Handling**: Made audio device change notifications safe to avoid dangling callbacks.

---

# HoAh Dictation v3.5.6

### Fixes
* **Microphone Access**: Added the required audio-input entitlement for Developer ID builds.

### Cleanup
* **Permissions**: Removed unused screen recording permission description.

---

# HoAh Dictation v3.5.5

### Improvements
* **Onboarding Refresh**: Clearer onboarding copy with updated localizations for a smoother first-run experience.
* **Update Check Gating**: The “Check for Updates” button now appears only on non–Mac App Store builds.
* **Developer ID Sparkle**: Updated entitlements and Sparkle setup for Developer ID signing.

---

# HoAh Dictation v3.5.4

### Enhancements
* **Icon Refresh**: Updated App Icon and Menu Bar Icon to strictly follow macOS Big Sur+ design guidelines for better size consistency and visual alignment.
* **Vintage Visualizer**: Increased sensitivity for the Vintage theme ink visuals, making them more responsive and lively.

---

# HoAh Dictation v3.5.3

### New Visualizers
* **Cyberpunk Waveform**: Experience audio visualization like never before with a liquid, high-resolution continuous waveform that pulsates with your voice.
* **Vintage Ink Dots**: A minimal, calming visualizer style featuring rounded, sparse ink dots.

### Improvements
* **Theme System**: Complete refactor of the Mini Recorder's visualization engine to be fully theme-driven, allowing for distinct shapes, sizes, and behaviors per theme.
* **Deterministic Visuals**: Visualizer randomness is now seeded for consistent aesthetic behavior across sessions.

---

# HoAh Dictation v3.5.0

### New Features
* **Auto Daily Export**: Automatically save each transcription to a daily Markdown log file in real-time. Configure your export folder in History settings and never lose a transcription again!
* **Fun Translation Styles**: New cute animal modes with authentic internet language styles:
  - 🐱 Cat: Lolspeak (EN) / 喵语 (ZH) / ネコ語 (JP)
  - 🐶 Dog: DoggoLingo (EN) / 汪语 (ZH) / ワン語 (JP)
  - 🐦 Bird: Birb language (EN) / 鸟语 (ZH) / 鳥語 (JP)
  - 🐰 Bunny: Soft shy bunny style
* **Social Media Styles**: ✨ 小红书风 (Xiaohongshu), 🎀 软妹风 (Soft Girl), 🎭 中二病 (Chuunibyou)

### Improvements
* **Most Recently Used**: Translation targets now automatically move to the front of the list when used.
* **Centralized State Management**: Translation language settings are now properly synchronized across all views.
* **Collapsible Settings**: Auto export settings now use a compact collapsible design.

---

# HoAh Dictation v3.4.7

### New Features
* **Daily Markdown Export**: You can now export your transcription history as daily Markdown files, neatly organized in a folder with `hoah-` prefix. Perfect for Obsidian or other note-taking apps!
* **Improved Localization**: Refined Chinese and English translations for export features.

### Improvements
* **CSV Export**: The option to export as a single CSV file is now clearly labeled.
* **Release Pipeline**: Migrated to a new secure release infrastructure for better stability.

### Fixes
* **Localization Fixes**: Resolved XML structure issues in localization files.

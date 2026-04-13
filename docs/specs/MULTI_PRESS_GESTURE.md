# Multi-Press Option Gesture Spec

## Overview

Extend the Option hotkey to support **double-press auto-send** in addition to the existing single-press behavior. Inspired by AirPods multi-press gestures.

## Motivation

Users often dictate directly into chat inputs or message boxes. This feature lets them:
- **Auto-send** a transcription by pasting + pressing Enter with a quick double-press
- **Append** a recording onto the previous transcription with a dedicated optional shortcut

## Gesture Definitions

The first press always starts recording immediately (zero delay). Subsequent quick presses within a detection window modify the recording mode without stopping.

### Detection Window

- **Window duration**: 500ms after each press event
- **Resets**: Each additional press within the window resets the timer
- **Based on**: OS double-click interval (~400-500ms), human double-click speed (150-500ms for most users)

### The Four Cases

#### Normal Mode (existing behavior)

| Case | Gesture | Description |
|------|---------|-------------|
| 1 | `Press↓ Release↑ ... Press↓ Release↑` | Tap to start, tap to stop |
| 2 | `Press↓ ............ Release↑` | Hold to record, release to stop |

#### Auto-Send Mode (double-press, requires setting enabled)

| Case | Gesture | Description |
|------|---------|-------------|
| 3 | `Press↓ Release↑ Press↓ Release↑ ... Press↓ Release↑` | Double-tap to switch to auto-send, tap to stop |
| 4 | `Press↓ Release↑ Press↓ ............ Release↑` | Double-tap with hold, release to stop in auto-send mode |

### Conflict Avoidance

The key to distinguishing cases is tracking press/release pairs within the detection window:

```
First Press↓ → Start recording + open 500ms window
  │
  ├─ No Release↑ within window → Case 2 (hold mode), Release↑ stops recording
  │
  └─ Release↑ within window → Count = 1, waiting...
      │
      ├─ No Press↓ within window → Window expires, locked to Normal mode (Case 1)
      │
      └─ Press↓ within window → Count = 2 (auto-send mode)
          │
          ├─ No Release↑ within window → Case 4 (auto-send + hold), Release↑ stops
          │
          └─ Release↑ within window → Count = 2, waiting...
              │
              └─ No Press↓ within window → Window expires, locked to Auto-send (Case 3)
```

After the detection window expires and mode is locked:
- **Cases 1, 3**: Next Option press toggles recording off
- **Cases 2, 4**: Option release stops recording

Presses beyond 2 within the window are capped at auto-send mode (count = 2).

### Settings Disabled Behavior

The multi-press detection window only opens when **double-press auto-send** is enabled.

When the setting is disabled, the app keeps the legacy hotkey behavior. This ensures no behavior changes for users who do not opt in.

## Mode Behaviors

### Normal Mode

Current behavior unchanged:
1. Record audio
2. Transcribe
3. Optional AI enhancement
4. Save as new `Transcription` entry
5. Optional auto-paste of result

### Auto-Send Mode

Transcribe and automatically send:

1. Record audio
2. Transcribe
3. Optional AI enhancement
4. Save as new `Transcription` entry (normal)
5. Paste result into the active application
6. Simulate Return/Enter key press to send

## Settings

Two controls under the Hotkey settings section:

| Setting | Key | Default | Description |
|---------|-----|---------|-------------|
| Double-press to auto-send | `multiPressGestureAutoSendEnabled` | `false` | Enable double-press Option to auto-paste and send |
| Append shortcut | `toggleMiniRecorderAppend` | not set | Start/stop a recording in append mode using a user-assigned shortcut |

## Visual Feedback

The mini recorder should indicate the current mode during the detection window:

- **Normal**: Current appearance (no change)
- **Auto-Send**: Show send indicator (e.g., arrow-up icon or "AutoSend" badge)
- **Append**: Show append indicator (e.g., link icon or "Append" badge) when the append shortcut starts recording

Mode indicator should animate in when mode changes during multi-press detection.

## Implementation Files

| Component | File | Changes |
|-----------|------|---------|
| Gesture detection | `HoAh/Managers/Input/HotkeyManager.swift` | Multi-press counting, window timer, mode determination |
| Recording mode enum | `HoAh/Whisper/WhisperState.swift` | `RecordingMode` enum, mode-aware transcription flow |
| Append logic | `HoAh/Whisper/WhisperState.swift` | Append text/enhancement to the previous `Transcription` and refresh clipboard |
| Auto-send logic | `HoAh/Whisper/WhisperState.swift` | Paste + simulate Enter after transcription |
| Settings | `HoAh/Models/AppSettings.swift` (or equivalent) | One boolean setting plus one dedicated shortcut binding |
| Settings UI | Settings view | Auto-send toggle plus append shortcut recorder |
| Mini recorder UI | `HoAh/Views/Recorder/` | Mode indicator display |

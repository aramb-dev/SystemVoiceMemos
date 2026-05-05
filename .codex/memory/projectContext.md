# Project Context

## Project
SystemVoiceMemos is a privacy-first macOS utility for capturing and managing audio memos. The app is built with SwiftUI, SwiftData, AVFoundation, ScreenCaptureKit, Sparkle, and a newer Core Audio process-tap recording path.

## Product Goals
- Capture system audio with minimal friction and clear recording state.
- Keep all recording and processing local to the user's Mac.
- Provide native macOS management, playback, Finder reveal, export, settings, onboarding, and help experiences.
- Keep the default UI simple while allowing advanced recording/export options for power users.

## Current Architecture
- `SystemVoiceMemos/` contains SwiftUI views, SwiftData models, app state, settings, onboarding, permissions, and feature-specific helpers.
- Root-level `SystemAudioRecorder.swift` owns recording backends and sample-buffer writing.
- Root-level `SystemAudioPlayer.swift` owns playback, track volume controls, and export.
- `SystemVoiceMemos/CoreAudioTapRecorder.swift` provides the macOS 14.2+ Core Audio tap capture backend.
- `SystemVoiceMemos/RecordingSource.swift` persists the selected recording source.
- `SystemVoiceMemos/SystemVoiceMemos.help/` contains the native Help Book.
- `build-and-sign` handles release packaging, notarization, Sparkle signing, and appcast snippet/update flow.

## Verification Commands
- Build: `xcodebuild -scheme SystemVoiceMemos -destination 'platform=macOS' build`
- Tests: `xcodebuild test -scheme SystemVoiceMemos -destination 'platform=macOS'`
- Xcode: open `SystemVoiceMemos.xcodeproj`, then use Cmd-B, Cmd-R, or Cmd-U.

## Important Runtime Requirements
- macOS target is currently configured at 14.0, while the Core Audio tap source is guarded for macOS 14.2+.
- Legacy ScreenCaptureKit system-audio capture depends on Screen Recording permission.
- Microphone-only and legacy system+mic capture depend on microphone permission.
- Release packaging expects Sparkle tooling, private key, optional notarization credentials, and `create-dmg`.

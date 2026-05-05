# CLAUDE.md

## Project
**What**: macOS app that captures system audio and microphone audio, stores recordings as local M4A files, and provides SwiftUI controls for playback, folders, sharing, export, settings, onboarding, and help.
**Stack**: Swift, SwiftUI, SwiftData, AVFoundation, ScreenCaptureKit, Core Audio process taps, Sparkle, Xcode 16+, macOS 14.0+.

## Commands
| Command | Description |
|---------|-------------|
| `open SystemVoiceMemos.xcodeproj` | Open the project in Xcode |
| `./build-and-run.sh` | Build and launch the app |
| `xcodebuild -scheme SystemVoiceMemos -destination 'platform=macOS' build` | CLI build verification |
| `xcodebuild test -scheme SystemVoiceMemos -destination 'platform=macOS'` | Run unit/UI tests |
| `./build-and-sign Production` | Release build, DMG, optional notarization, Sparkle signing |
| `./build-and-sign Production --bump patch` | Production release with version bump |

## Architecture
- `SystemVoiceMemos/` contains SwiftUI views, SwiftData models, settings, onboarding, permissions, app state, and the native Help Book.
- `SystemAudioRecorder.swift` coordinates recording backends and writes sample buffers.
- `SystemVoiceMemos/CoreAudioTapRecorder.swift` implements the macOS 14.2+ no-screen-sharing Core Audio tap source.
- `SystemVoiceMemos/RecordingSource.swift` persists source selection: Core Audio tap, legacy ScreenCaptureKit, or microphone-only.
- `SystemAudioPlayer.swift` handles playback, track volume controls, and export to M4A, MP3, WAV, and AIFF.
- `RecordingManager.swift` creates/finalizes SwiftData recording entities and reconciles file metadata after capture.
- `build-and-sign` handles app packaging, notarization/stapling, Sparkle signing, and appcast snippet/update flow.

---
## Mistakes to Avoid
- Don't ignore Screen Recording permission warnings for legacy ScreenCaptureKit capture; grant via System Settings > Privacy & Security.
- Core Audio tap capture avoids Screen Recording UI but requires macOS 14.2+; keep the legacy ScreenCaptureKit fallback working.
- Microphone-only and legacy system+mic paths require microphone permission and selected input-device handling.
- Avoid running concurrent system audio recorders; they conflict with capture
- Release packaging depends on Sparkle tools, `~/Downloads/sparkle_private_key` or `SPARKLE_PRIVATE_KEY`, `create-dmg`, and optional notarization credentials.
- Keep appcast enclosure `length` and `sparkle:edSignature` aligned with the generated DMG.
- Use 4-space indentation and upper-camel-case for types, lower-camel-case for properties
- Don't create overly detailed comments; keep them light and only for non-obvious logic

## Learned Patterns
- SwiftUI views and helpers coexist in `SystemVoiceMemos/`; core playback/recording logic at repo root
- Tests split between unit tests (`SystemVoiceMemosTests/`) and UI tests (`SystemVoiceMemosUITests/`)
- Recordings are local files plus SwiftData metadata; duration and track count are finalized after capture by reading the asset.
- Source selection lives in UserDefaults via `RecordingSource.current`, so recording setup should read source state once at start.
- PR conventions: short imperative verbs with type prefixes (e.g., `feat: add in-app playback`)
- UI-facing changes require screenshots or screen recordings in PR descriptions

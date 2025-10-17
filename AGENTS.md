# Repository Guidelines

## Project Structure & Module Organization
- `SystemVoiceMemos/` holds SwiftUI views, models, and app logic. Playback helpers live at repo root (`SystemAudioRecorder.swift`, `SystemAudioPlayer.swift`) while the Xcode project (`SystemVoiceMemos.xcodeproj/`) wires everything together.
- Tests sit in `SystemVoiceMemosTests/` and `SystemVoiceMemosUITests/`. Assets (icons, etc.) are managed through `SystemVoiceMemos/Assets.xcassets/`.

## Build, Test, and Development Commands
- `open SystemVoiceMemos.xcodeproj`: launch the workspace in Xcode.
- In Xcode, use `⌘B` to build, `⌘R` to run the macOS app, and `⌘U` to execute unit/UI tests.
- Command-line builds: `xcodebuild -scheme SystemVoiceMemos -destination 'platform=macOS' build` replicates the IDE build.

## Coding Style & Naming Conventions
- Swift files follow 4-space indentation, upper-camel-case types (`RecordingEntity`), and lower-camel-case methods/properties (`startRecording`).
- SwiftUI view structs live alongside supporting helpers; keep comments lightweight and only for non-obvious logic.
- Format code with Xcode’s `Editor ▸ Structure ▸ Re-Indent` when touching files.

## Testing Guidelines
- Unit tests use XCTest (`SystemVoiceMemosTests`); UI flows go under `SystemVoiceMemosUITests`.
- Name tests descriptively (e.g., `testStartRecordingCreatesFile`).
- From Xcode, select a target and press `⌘U`; CLI alternative: `xcodebuild test -scheme SystemVoiceMemos -destination 'platform=macOS'`.

## Commit & Pull Request Guidelines
- Follow the existing conventional-style history: short imperative verbs with type prefixes (`feat: add in-app playback`, `docs: add README`).
- Each PR should explain scope, note testing performed, and include screenshots or screen recordings for UI-facing changes. Reference related issues when available and call out permission/configuration steps (Screen Recording, audio) if they affect verification.

## Security & Configuration Tips
- Ensure Screen Recording permission is granted via **System Settings ▸ Privacy & Security ▸ Screen Recording** before testing capture.
- Audio capture relies on the main display; avoid running concurrent system audio recorders to prevent conflicts.

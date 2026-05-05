# Conventions

## Repository Conventions
- Swift files use 4-space indentation.
- Types are UpperCamelCase.
- Methods and properties are lowerCamelCase.
- Keep comments lightweight and limited to non-obvious logic.
- SwiftUI view structs live near supporting helpers.
- Root-level playback helpers currently include `SystemAudioRecorder.swift` and `SystemAudioPlayer.swift`.

## Build And Test
- Prefer Xcode for normal local development.
- Use `xcodebuild -scheme SystemVoiceMemos -destination 'platform=macOS' build` for CLI build verification.
- Use XCTest targets under `SystemVoiceMemosTests/` and `SystemVoiceMemosUITests/`.

## Git
- Follow Conventional Commit style, e.g. `feat: add in-app playback`.
- Keep commits medium-sized and scoped to the task.
- Do not stage unrelated local agent/config files unless requested.

## User Preferences To Respect
- Ask before introducing new files, tools, or dependencies unless the request clearly implies them.
- Prefer incremental patches over full-file rewrites.
- Keep explanations focused on project-specific details.

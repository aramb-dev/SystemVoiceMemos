# Active Context

## Branch
- Current branch: `codex/core-audio-tap-capture`
- Recent commit: `a46ae97 fix: address export and appcast review issues`

## Current Branch Work
- Adds Core Audio process-tap recording as the default no-screen-sharing system audio source on macOS 14.2+.
- Keeps legacy ScreenCaptureKit system audio as a selectable source.
- Adds microphone-only recording.
- Adds toolbar/settings controls for recording source, microphone inclusion, and input device selection.
- Adds WAV, AIFF, and MP3 export support.
- Adds a native macOS Help Book and updates release/appcast tooling.

## Recent Review Fixes
- `SystemAudioPlayer.swift`: PCM export now checks `AVAssetWriter.startWriting()`, cancels the reader, and throws instead of waiting forever when writing cannot start.
- `build-and-sign`: appcast patching now recognizes both `FILL_IN_*` placeholders and the placeholders documented in `appcast.xml`.

## Working Tree Notes
- `.agents/` and `.codex/` are untracked local agent/config state.
- Memory bank files were initialized under `.codex/memory/`.
- Do not accidentally include unrelated local agent state in product commits unless explicitly requested.

## Last Known Verification
- `xcodebuild -scheme SystemVoiceMemos -destination 'platform=macOS' build` succeeded after the review fixes.
- Build emitted warnings in `SystemAudioPlayer.swift` about unnecessary `await` on synchronous `insertTimeRange` calls and non-Sendable AVFoundation captures inside a sendable closure.

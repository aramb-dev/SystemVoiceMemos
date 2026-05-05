# Active Context

## Product State
- Core Audio process-tap recording is the default no-screen-sharing system audio source on macOS 14.2+.
- Legacy ScreenCaptureKit system audio remains available as a fallback/source option.
- Microphone-only recording is supported.
- Toolbar/settings controls configure recording source, microphone inclusion, and input device selection.
- Export supports M4A, MP3, WAV, and AIFF.
- The app includes a native macOS Help Book and Sparkle release/appcast tooling.

## Durable Implementation Notes
- `SystemAudioPlayer.swift` should fail fast if PCM export cannot start writing; do not enter an async writer loop after `AVAssetWriter.startWriting()` returns `false`.
- `build-and-sign` appcast patching should stay aligned with the placeholders documented in `appcast.xml`.
- Memory bank files live under `.codex/memory/`.
- Do not stage unrelated local agent/config files unless the user explicitly asks.

## Last Known Verification
- `xcodebuild -scheme SystemVoiceMemos -destination 'platform=macOS' build` is the canonical CLI build check.
- Build emitted warnings in `SystemAudioPlayer.swift` about unnecessary `await` on synchronous `insertTimeRange` calls and non-Sendable AVFoundation captures inside a sendable closure.

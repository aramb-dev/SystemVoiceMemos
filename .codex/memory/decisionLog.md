# Decision Log

## 2026-05-05: Store Memory Bank Under `.codex/memory`
The repo already contains Codex-local configuration under `.codex/`, so the Memory Bank was initialized at `.codex/memory/` to keep agent state colocated.

## 2026-05-05: Keep Review Fix Commit Narrow
The review fixes were committed as `a46ae97` with only `SystemAudioPlayer.swift` and `build-and-sign` staged. Untracked `.agents/` and `.codex/` state was intentionally left out.

## Current Product/Architecture Decisions From Repo Docs
- Favor native macOS SwiftUI patterns and standard system controls.
- Keep audio processing local and privacy-preserving.
- Use SwiftData for recording metadata.
- Use ScreenCaptureKit for legacy system audio capture and AVFoundation/Core Audio for playback/export/tap capture.
- Use Sparkle appcast release flow for updates.

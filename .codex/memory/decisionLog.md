# Decision Log

## 2026-05-05: Store Memory Bank Under `.codex/memory`
The repo already contains Codex-local configuration under `.codex/`, so the Memory Bank was initialized at `.codex/memory/` to keep agent state colocated.

## 2026-05-05: Keep Memory Durable
Memory files should describe the whole project state. Branch names and transient commit bookkeeping belong in git history, not long-lived project memory.

## Current Product/Architecture Decisions From Repo Docs
- Favor native macOS SwiftUI patterns and standard system controls.
- Keep audio processing local and privacy-preserving.
- Use SwiftData for recording metadata.
- Use ScreenCaptureKit for legacy system audio capture and AVFoundation/Core Audio for playback/export/tap capture.
- Use Sparkle appcast release flow for updates.

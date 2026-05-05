# Progress

## Completed
- Project orientation captured from `README.md`, `AGENTS.md`, and `conductor/` docs.
- Memory Bank initialized in `.codex/memory/`.
- Durable Claude/Codex project memory now reflects the full app state.

## In Progress
- Continue using the memory files as whole-project context.

## Open Follow-Ups
- Consider addressing build warnings in `SystemAudioPlayer.swift` if/when strict concurrency or warning cleanliness becomes a gate.
- Validate recording behavior manually on macOS with real permissions and audio devices:
  - Core Audio tap source.
  - Legacy ScreenCaptureKit source.
  - Legacy system+mic source.
  - Microphone-only source.
  - M4A, MP3, WAV, and AIFF export paths.

# CLAUDE.md

## Quick Reference
```bash
/boris <task>        # Full workflow
/session-start       # Load context
/session-end         # Save context
/verify-all          # Run checks
/commit-push-pr      # Git workflow
/undo                # Revert change
/checkpoint [name]   # Save point
/fix-issue <num>     # Fix issue
```

## Project
**What**: macOS app that captures system audio using ScreenCaptureKit and stores recordings as M4A files with SwiftUI controls
**Stack**: Swift, SwiftUI, ScreenCaptureKit, SwiftData, Xcode 16+, macOS 15.0+

## Commands
| Command | Description |
|---------|-------------|
| `./build-and-run.sh` | Build the app |

---
## Mistakes to Avoid
- Don't ignore Screen Recording permission warnings—grant via System Settings > Privacy & Security
- Avoid running concurrent system audio recorders; they conflict with capture
- Use 4-space indentation and upper-camel-case for types, lower-camel-case for properties
- Don't create overly detailed comments; keep them light and only for non-obvious logic

## Learned Patterns
- SwiftUI views and helpers coexist in `SystemVoiceMemos/`; core playback/recording logic at repo root
- Tests split between unit tests (`SystemVoiceMemosTests/`) and UI tests (`SystemVoiceMemosUITests/`)
- PR conventions: short imperative verbs with type prefixes (e.g., `feat: add in-app playback`)
- UI-facing changes require screenshots or screen recordings in PR descriptions
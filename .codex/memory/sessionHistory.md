# Session History

## 2026-05-05
- Reviewed the current audio capture/export changes.
- Found two review issues:
  - PCM export ignored `AVAssetWriter.startWriting()` failure.
  - Release script appcast placeholder matching did not match the template in `appcast.xml`.
- Fixed both issues and verified with `xcodebuild -scheme SystemVoiceMemos -destination 'platform=macOS' build`.
- Ran `source-command-memory-init` and initialized `.codex/memory/` with project context, active context, progress, decision log, conventions, and this session history.
- Updated `CLAUDE.md` and `.codex/memory/` to describe the whole project state.

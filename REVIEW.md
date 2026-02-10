# SystemVoiceMemos - Comprehensive App Review

## 1. Ratings (1-10)

| Dimension | Score | Justification |
|---|---|---|
| **Visual Design & Consistency** | 7/10 | Onboarding is polished with liquid-glass effects. Main app uses standard macOS chrome well. Floating panel is clean. However, the About window uses a bare `NSAlert` instead of a proper window, and there's no app icon treatment visible in the codebase. |
| **UX & Information Architecture** | 7/10 | Three-column layout follows Apple conventions. Folder system, favorites, soft-delete, and search are well-organized. Keyboard shortcuts are comprehensive. However, the "Assign Folder" dialog uses a raw `NSTextField` in an `NSAlert` instead of a proper picker, and there's no drag-and-drop for organizing recordings. |
| **Accessibility (WCAG)** | 3/10 | Almost no `accessibilityLabel` on interactive controls. Only the settings stepper has one. No VoiceOver announcements for recording state changes. No reduced-motion alternatives for onboarding animations. Waveform is purely visual with no accessible representation. |
| **Performance & Responsiveness** | 7/10 | Audio pipeline is efficient with ScreenCaptureKit. Waveform analysis runs on a background queue with cancellation. However, `filteredRecordings` and `userFolders` are recomputed on every render (no caching). The `recordingsHash` linear scan runs on every SwiftData change. |
| **Reliability & Error Handling** | 4/10 | Crash recovery for incomplete recordings is good. But errors are overwhelmingly handled with `print()` + `try?` — the user never sees what went wrong. `startNewRecording` silently fails if the recorder throws. No structured error types for most operations. |
| **Security & Privacy** | 6/10 | Screen sharing exclusion is a strong privacy feature. Local-only storage is good. However: the app requests `com.apple.security.cs.allow-unsigned-executable-memory` (needed for Sparkle but widens attack surface), there's **no App Sandbox** entitlement, and the Sparkle update feed uses HTTP-upgradable URLs over raw GitHub hosting with no certificate pinning. |
| **Code Quality & Maintainability** | 5/10 | Modern Swift patterns (@Observable, async/await, SwiftData) are used well. Files are generally well-organized. But `ContentView.swift` at 973 lines is a god-view with business logic, file operations, and UI all mixed together. Folder-Recording references use string matching instead of model relationships. Massive style duplication in `OnboardingView` (the capsule button style is copy-pasted 4 times). |
| **Architecture & Scalability** | 5/10 | Service boundaries are reasonably clear (recorder, player, manager). But: `recordingsLocation` setting exists in the UI but `AppDirectories.recordingsDir()` never reads it — recordings always go to the hardcoded Application Support path. NotificationCenter is used as an event bus between App and ContentView instead of direct bindings or `@Environment`. No protocol abstractions make testing impossible. |
| **Test Coverage & CI/CD** | 1/10 | A single placeholder test exists with `// Write your test here`. Zero actual test coverage. No CI pipeline in the repo. The build scripts are functional but there's no automated quality gate. |

---

## 2. Top 10 Issues/Opportunities

### 1. Zero Test Coverage

- **What's wrong**: Single placeholder test. No unit, integration, or UI tests.
- **Evidence**: `SystemVoiceMemosTests.swift:12-14` — empty test body. No CI config in repo.
- **Severity**: **High** (Engineering). Any refactor or feature addition risks silent regressions in the audio pipeline, data persistence, or recording lifecycle.
- **Fix**: Write unit tests for `RecordingManager`, `PlaybackManager`, `WaveformAnalyzer`, and `LocationNamingService`. Add integration tests for the record-stop-finalize flow using mock audio files.

### 2. ContentView God-View (973 lines)

- **What's wrong**: ContentView owns business logic (file deletion, folder renaming, crash recovery, duration refresh, share handling) alongside all UI coordination.
- **Evidence**: `ContentView.swift` contains `performDeletion()`, `clearAllDeletedRecordings()`, `recoverIncompleteRecordings()`, `refreshDurationsIfNeeded()`, `promptForFolder()` — all business logic in a View.
- **Severity**: **High** (Engineering). Impossible to test business logic independently. Changes to UI risk breaking recording/deletion logic.
- **Fix**: Extract a `ContentViewModel` (or multiple focused view models) to hold recording operations, folder management, and selection state. ContentView becomes a thin rendering layer.

### 3. Silent Error Swallowing

- **What's wrong**: ~15 instances of `try?` with no user feedback and `print()` as the only error reporting.
- **Evidence**: `ContentView.swift:367-371` trashItem error just prints. `RecordingManager.swift:193` startRecording error just prints. `ContentView.swift:340` duration load error just prints.
- **Severity**: **High** (User). A recording that fails to start or save gives the user zero feedback — they think it's recording when it's not.
- **Fix**: Introduce a centralized error presentation mechanism (e.g., `@Published var userError: AppError?` on a shared model) that surfaces actionable alerts for recording failures, file system errors, and permission issues.

### 4. `recordingsLocation` Setting Does Nothing

- **What's wrong**: The Settings UI lets users pick a custom recordings directory, but it's never read by the file system layer.
- **Evidence**: `SettingsWindow.swift:97` has `@AppStorage("recordingsLocation")`. But `FileLocations.swift` (the `AppDirectories.recordingsDir()` method) uses a hardcoded Application Support path. The custom path is stored but ignored.
- **Severity**: **High** (User/Product). This is a broken feature — users think they've changed the storage location but recordings keep going to the default path.
- **Fix**: Either wire `AppDirectories.recordingsDir()` to read and respect the `recordingsLocation` UserDefault, or remove the setting from the UI to avoid confusion.

### 5. Auto-Delete Never Executes

- **What's wrong**: Settings has an "Auto Cleanup" toggle with configurable retention days, but there's no timer or background task that actually deletes expired recordings.
- **Evidence**: `SettingsWindow.swift:100-101` stores `autoDeleteEnabled` and `autoDeleteAfterDays`. Searched entire codebase — `autoDeleteEnabled` and `autoDeleteAfterDays` are never read outside SettingsWindow. No scheduled cleanup exists.
- **Severity**: **Med** (User/Product). Users configure auto-cleanup expecting it to work, but trash accumulates indefinitely.
- **Fix**: Add a cleanup check on app launch (and optionally on a timer) that queries `recordings.filter { $0.deletedAt != nil && daysSince(deletedAt) > autoDeleteAfterDays }` and deletes them.

### 6. Folder-Recording Relationship Uses String Matching

- **What's wrong**: `RecordingEntity.folder` is a plain `String?` referencing a folder name, not a SwiftData relationship.
- **Evidence**: `RecordingEntity.swift:41` — `var folder: String?`. Renaming requires iterating all recordings (`ContentView.swift:875`). No referential integrity.
- **Severity**: **Med** (Engineering). Renaming a folder requires manually updating every recording. If the update loop is interrupted, orphaned references occur.
- **Fix**: Add a proper `@Relationship` from `RecordingEntity` to `FolderEntity`. SwiftData will handle cascading updates. Migration can be done with a lightweight SwiftData migration.

### 7. No App Sandbox

- **What's wrong**: The app runs without App Sandbox, and the entitlements only contain `com.apple.security.cs.allow-unsigned-executable-memory`.
- **Evidence**: `SystemVoiceMemos.entitlements` — no `com.apple.security.app-sandbox` key. No network or file access entitlements either.
- **Severity**: **Med** (Security). Without sandboxing, the app has unrestricted file system and network access. Mac App Store distribution is impossible. Compromised Sparkle updates could have full system access.
- **Fix**: Enable App Sandbox with `com.apple.security.temporary-exception.audio-unit-host` and `com.apple.security.device.audio-input`. Add required entitlements for file access (user-selected files) and network (Sparkle updates).

### 8. Accessibility Gaps

- **What's wrong**: Interactive controls lack accessibility labels. No VoiceOver announcements for state changes. Waveform is visual-only.
- **Evidence**: Record button, playback controls, floating panel buttons, sidebar items — none have `.accessibilityLabel()`. Only `SettingsWindow.swift:171` has one: `.accessibilityLabel("Auto cleanup days")`.
- **Severity**: **Med** (User). Screen reader users cannot operate the app.
- **Fix**: Add `.accessibilityLabel()` and `.accessibilityHint()` to all interactive controls. Add `.accessibilityValue()` for recording state, playback progress. Post `UIAccessibility.Notification` for state changes.

### 9. Onboarding Button Style Duplication

- **What's wrong**: The capsule button with glass highlight is copy-pasted 4 times across `OnboardingView` (welcome, permissions, completion x2).
- **Evidence**: `OnboardingView.swift:179-207`, `260-293`, `365-398` — nearly identical capsule + gradient + overlay + shadow code blocks. Also `HexagonShape` at line 497 appears completely unused.
- **Severity**: **Low** (Engineering). Makes visual changes require editing 4 places. `HexagonShape` is dead code.
- **Fix**: Extract a `GlassCapsuleButtonStyle: ButtonStyle` that encapsulates the glass effect. Delete `HexagonShape`.

### 10. NotificationCenter as Event Bus

- **What's wrong**: Menu commands communicate with ContentView via `NotificationCenter` posts, bypassing SwiftUI's data flow.
- **Evidence**: `SystemVoiceMemosApp.swift:61-62` posts `.startRecording`. `ContentView.swift:118` receives with `.onReceive`. Six different notification names defined for internal app communication.
- **Severity**: **Low** (Engineering). Makes the control flow hard to trace. No compile-time safety. Notifications are fire-and-forget with no error propagation.
- **Fix**: Use a shared `@Observable` AppState model or `FocusedValue` / `FocusedBinding` to pass commands from menu to content view with type safety.

---

## 3. Prioritized Improvement Plan

### Quick Wins (1-3 days)

| # | Task | Effort | Impact |
|---|---|---|---|
| 1 | ~~**Fix or remove the recordingsLocation setting** — either wire it into `AppDirectories.recordingsDir()` or remove the UI to stop confusing users~~ | S | High (eliminates broken feature) | **Done** |
| 2 | ~~**Implement auto-delete cleanup** — add a check on app launch that purges expired soft-deleted recordings~~ | S | Med (delivers a promised feature) | **Done** |
| 3 | ~~**Surface recording errors to the user** — when `startRecording` fails, show an alert instead of just printing~~ | S | High (prevents silent recording loss) | **Done** |
| 4 | ~~**Delete dead code** — remove unused `HexagonShape`, remove stale `import Combine` in `SystemAudioRecorder.swift` (Combine isn't used)~~ | S | Low (cleanliness) | **Partial** — `import Combine` remains in `UpdaterManager.swift` |
| 5 | ~~**Add accessibility labels** to record button, play/pause, stop button, floating panel controls, and waveform seek slider~~ | S | Med (basic accessibility compliance) | **Done** |

### Mid-Term (1-3 weeks)

| # | Task | Effort | Impact | Depends on |
|---|---|---|---|---|
| 6 | ~~**Extract ContentViewModel** — move business logic (recording ops, folder management, crash recovery, duration refresh) out of ContentView into testable view models~~ | M | High (testability, maintainability) | — | **Done** |
| 7 | ~~**Write core test suite** — unit tests for PlaybackManager, RecordingManager, WaveformAnalyzer, LocationNamingService, TimeFormatter~~ | M | High (regression safety) | #6 | **Done** |
| 8 | ~~**Extract GlassCapsuleButtonStyle** — deduplicate the 4 copied capsule button blocks in OnboardingView~~ | S | Low (DRY) | — | **Done** |
| 9 | ~~**Replace NotificationCenter event bus** — use `@Observable` AppState or FocusedValue for menu-to-view communication~~ | M | Med (type safety, traceability) | — | **Done** |
| 10 | ~~**Migrate folder relationship to SwiftData @Relationship** — replace string-based folder references with proper model relationships~~ | M | Med (data integrity) | — | **Done** |

### Long-Term (1-3 months)

| # | Task | Effort | Impact | Depends on |
|---|---|---|---|---|
| 11 | **Enable App Sandbox** — add sandbox entitlements, audit file access patterns, test with ScreenCaptureKit under sandbox | L | High (security, App Store eligibility) | — |
| 12 | **Add CI pipeline** — GitHub Actions with `xcodebuild test`, linting (SwiftLint), and build verification on PR | M | High (quality gate) | #7 |
| 13 | **Structured logging** — replace all `print()` with `os.Logger` for proper subsystem/category filtering and persistence | M | Med (debuggability) | — |
| 14 | **Integration tests for audio pipeline** — test record-pause-resume-stop-finalize flow with mock SCStream output | L | High (confidence in core feature) | #6, #7 |
| 15 | **Add keyboard navigation and VoiceOver audit** — full accessibility pass with reduced-motion support | M | Med (inclusive UX) | #5 |

---

## 4. Implementation Recommendations

### State Management & Component Boundaries

- **Extract `RecordingsViewModel`** owning `filteredRecordings`, `selectedRecordingID`, search, folder filtering. ContentView observes it.
- **Extract `RecordingActionsService`** for delete, rename, move-to-folder, share. Takes `ModelContext` as dependency injection.
- **Use `@Observable` everywhere** — `PlaybackManager` still uses `ObservableObject`/`@Published`. Migrating to `@Observable` reduces boilerplate and improves SwiftUI update granularity (only properties accessed in a view body trigger updates).

### Error/Loading/Empty State Patterns

- Define a `UserFacingError` enum conforming to `LocalizedError` with `.recordingFailed(underlying:)`, `.playbackFailed(recording:)`, `.permissionDenied(type:)`.
- Use a single `.alert(item:)` binding on a shared error publisher rather than scattering error handling across views.
- Add an explicit empty state for the recordings list (currently there's `EmptyDetailState()` for the detail panel but no empty state when the list itself is empty).

### Logging/Analytics/Monitoring

- Replace all `print("emoji text")` with `os.Logger(subsystem: "com.aramb-dev.SystemVoiceMemos", category: "Recording")`.
- `GrowthMetricsTracker` is fine for local counters but consider instrumenting recording duration distribution and failure rates for product insight (still local, no telemetry).

### Testing Strategy

- **Unit**: `PlaybackManager` (state transitions), `RecordingManager` (lifecycle), `WaveformAnalyzer` (data extraction), `LocationNamingService` (token sanitization), `TimeFormatter`.
- **Integration**: Record-stop-finalize cycle with a real temp file.
- **UI**: Snapshot tests for OnboardingView states, RecordingRow, PlaybackControlsView.
- **CI**: GitHub Actions running `xcodebuild test -scheme SystemVoiceMemos -destination 'platform=macOS'`.

### Performance Tactics

- Cache `filteredRecordings` — it's recomputed on every body evaluation. Move it to a ViewModel with proper change observation.
- `recordingsHash` does a linear scan of all recordings on every change — consider using `recordings.count` + last-modified date as a lighter proxy.
- `WaveformAnalyzer.extractWaveformData` could use vDSP from Accelerate (already imported but unused) for the normalization pass instead of `map`.

### Security/Privacy Checklist

- [ ] Enable App Sandbox
- [ ] Audit `com.apple.security.cs.allow-unsigned-executable-memory` — check if Sparkle 2.x still requires it
- [ ] Validate Sparkle's EdDSA signature verification is enabled (public key is present in Info.plist)
- [ ] Ensure `recordingsLocation` (when implemented) is restricted to user-chosen directories via security-scoped bookmarks
- [ ] Add `com.apple.security.network.client` entitlement for Sparkle update checks under sandbox
- [ ] Audit CLLocationManager usage — ensure location data is never persisted beyond the filename

---

## 5. Next Steps Checklist (Execute Immediately)

- [x] **Fix the `recordingsLocation` setting** — wired into `AppDirectories` via UserDefaults read in `FileLocations.swift`.
- [x] **Add error alerts for recording failures** — errors propagate via `lastError` and surface as `.alert()` in ContentView.
- [x] **Implement auto-delete on launch** — `ContentViewModel.autoDeleteExpiredRecordings()` runs in `.task {}`.
- [x] **Delete `HexagonShape`** — removed from OnboardingView.
- [x] **Add 5 accessibility labels** — record, play/pause, stop, floating panel controls, and waveform all labeled.

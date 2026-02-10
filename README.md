# SystemVoiceMemos

SystemVoiceMemos captures system audio on macOS using ScreenCaptureKit and stores each session as an M4A file. The SwiftUI client provides quick controls for starting and stopping a recording, browsing recent captures, and revealing them in Finder.

## Features
- Records system audio from the primary display using ScreenCaptureKit.
- Persists recordings with title, timestamp, and file metadata via SwiftData.
- Saves files as `m4a` into the app's recordings directory.
- Opens the recordings folder or an individual file in Finder with a single click.

## Requirements
- macOS 14.0 or later.
- Xcode 16 or later.
- Screen Recording permission (prompted on first run).

## Getting Started

### Prerequisites
- macOS 14.0 or later.
- Xcode 16 or later.

### Building in Xcode
1. Open `SystemVoiceMemos.xcodeproj` in Xcode.
2. Select the **SystemVoiceMemos** scheme and a destination (e.g., **My Mac**).
3. Press `Cmd + B` to build or `Cmd + R` to run.
4. On launch, ensure you grant the required **Screen Recording** permissions when prompted.

### Building from Command Line
You can build the project using `xcodebuild`. 

**Note:** If you encounter a signing error (e.g., "No signing certificate found"), you can build for verification only by disabling signing:

```bash
# Build for verification (skips signing)
xcodebuild -scheme SystemVoiceMemos -configuration Debug CODE_SIGNING_ALLOWED=NO
```

For a functional build that runs with all features (like Screen Capture), you should open the project in Xcode and select your own Development Team in the **Signing & Capabilities** tab.

The resulting binary will be located in the `build/Build/Products/Debug` directory (if using the command above).

### Release Packaging
Use the repo release helper:

```bash
# Debug/Release build only
./build-and-sign
./build-and-sign Release

# Production flow: Release build + DMG + notarize/staple (if configured) + Sparkle signature
./build-and-sign Production

# Production flow + automatic version bump
./build-and-sign Production --bump patch
./build-and-sign Production --bump minor
./build-and-sign Production --bump major

# Production flow + release notes for Sparkle appcast
./build-and-sign Production -p ./release-notes.txt
./build-and-sign Production -m "Adds city-based naming and share button polish."
```

Production mode expects:
- `create-dmg` installed and available on `PATH`
- Sparkle private key at `~/Downloads/sparkle_private_key` (or set `SPARKLE_PRIVATE_KEY`)
- Notarization credentials via either:
  - `NOTARY_PROFILE` (recommended), or
  - `APPLE_ID`, `APPLE_APP_SPECIFIC_PASSWORD`, `APPLE_TEAM_ID`

`--bump` uses `agvtool` to:
- update `MARKETING_VERSION` (semver bump)
- increment `CURRENT_PROJECT_VERSION`

Release notes options:
- `-p <path>` reads release notes from a text file (each non-empty line becomes a bullet in appcast).
- `-m <message>` uses a single inline release notes message.

## Troubleshooting
- If capture fails with CoreGraphics errors, confirm Screen Recording permission is granted in **System Settings → Privacy & Security → Screen Recording**.
- When testing, close other apps that might simultaneously capture system audio to avoid conflicts.

## License
MIT

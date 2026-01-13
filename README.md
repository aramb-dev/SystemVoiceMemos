# SystemVoiceMemos

SystemVoiceMemos captures system audio on macOS using ScreenCaptureKit and stores each session as an M4A file. The SwiftUI client provides quick controls for starting and stopping a recording, browsing recent captures, and revealing them in Finder.

## Features
- Records system audio from the primary display using ScreenCaptureKit.
- Persists recordings with title, timestamp, and file metadata via SwiftData.
- Saves files as `m4a` into the app's recordings directory.
- Opens the recordings folder or an individual file in Finder with a single click.

## Requirements
- macOS 15.0 or later.
- Xcode 16 or later.
- Screen Recording permission (prompted on first run).

## Getting Started

### Prerequisites
- macOS 15.0 or later.
- Xcode 16 or later.

### Building in Xcode
1. Open `SystemVoiceMemos.xcodeproj` in Xcode.
2. Select the **SystemVoiceMemos** scheme and a destination (e.g., **My Mac**).
3. Press `Cmd + B` to build or `Cmd + R` to run.
4. On launch, ensure you grant the required **Screen Recording** permissions when prompted.

### Building from Command Line
You can build the project using `xcodebuild`:

```bash
# Build the project
xcodebuild -scheme SystemVoiceMemos -configuration Release
```

The resulting binary will be located in the `build/Build/Products/Release` directory.

## Troubleshooting
- If capture fails with CoreGraphics errors, confirm Screen Recording permission is granted in **System Settings → Privacy & Security → Screen Recording**.
- When testing, close other apps that might simultaneously capture system audio to avoid conflicts.

## License
MIT

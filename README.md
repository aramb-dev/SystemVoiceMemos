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
You can build the project using `xcodebuild`. 

**Note:** If you encounter a signing error (e.g., "No signing certificate found"), you can build for verification only by disabling signing:

```bash
# Build for verification (skips signing)
xcodebuild -scheme SystemVoiceMemos -configuration Debug CODE_SIGNING_ALLOWED=NO
```

For a functional build that runs with all features (like Screen Capture), you should open the project in Xcode and select your own Development Team in the **Signing & Capabilities** tab.

The resulting binary will be located in the `build/Build/Products/Debug` directory (if using the command above).

## Troubleshooting
- If capture fails with CoreGraphics errors, confirm Screen Recording permission is granted in **System Settings → Privacy & Security → Screen Recording**.
- When testing, close other apps that might simultaneously capture system audio to avoid conflicts.

## License
MIT

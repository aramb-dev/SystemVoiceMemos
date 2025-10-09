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
1. Open `SystemVoiceMemos.xcodeproj` in Xcode.
2. Ensure the `com.apple.security.personal-information.screen-recording` entitlement is enabled (already added).
3. Build and run the `SystemVoiceMemos` scheme.
4. On launch, click **Start Recording** to begin capturing system audio. Click **Stop Recording** to finish and save the file.
5. Use the list to reveal recordings in Finder or delete entries you no longer need.

## Troubleshooting
- If capture fails with CoreGraphics errors, confirm Screen Recording permission is granted in **System Settings → Privacy & Security → Screen Recording**.
- When testing, close other apps that might simultaneously capture system audio to avoid conflicts.

## License
MIT

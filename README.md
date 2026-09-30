# ScreenRecord

A minimal Loom-style screen recorder for macOS. It lives in the menu bar and records your screen, a floating camera bubble, and your microphone into a single `.mov` file.

## Features

- **Start / Stop Recording** from the menu bar (3-second countdown before recording starts).
- **Camera bubble**: a circular, draggable webcam overlay that is captured in the recording. Toggle it on/off at any time.
- **Microphone**: records the default input device. Toggle mute at any time, even mid-recording.
- Records the display the mouse pointer is on, at native resolution (capped at 4K), 30 fps, H.264 + AAC.
- Recordings are saved to `~/Movies/ScreenRecord/` and revealed in Finder when you stop.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15+ or the Swift 5.9+ command line tools

## Build & run

```sh
make run        # builds build/ScreenRecord.app and opens it
```

Other targets: `make app` (build only), `make clean`.

Launch the app via `open build/ScreenRecord.app` (or Finder), not by running the binary directly, so macOS attributes the camera, microphone, and screen recording permissions to ScreenRecord instead of your terminal.

You can also download a prebuilt `ScreenRecord.zip` from the **Build** workflow artifacts on GitHub Actions. It is ad-hoc signed, so the first time: right-click the app → **Open**, or run `xattr -dr com.apple.quarantine ScreenRecord.app`.

## Permissions

On first use macOS asks for:

1. **Screen Recording**: System Settings → Privacy & Security → Screen Recording. Enable ScreenRecord, then quit and relaunch it.
2. **Camera** and **Microphone**: prompted automatically the first time they are used.

The app is ad-hoc signed, so after rebuilding macOS may ask for Screen Recording permission again. If recording silently fails, remove ScreenRecord from the Screen Recording list and add it back.

## Project layout

```
Package.swift                         Swift package (single executable target)
App/Info.plist                        App bundle metadata + privacy usage strings
scripts/build-app.sh                  Builds and ad-hoc signs build/ScreenRecord.app
Sources/ScreenRecord/
  ScreenRecordApp.swift               Menu bar UI
  RecorderController.swift            Recording state, permissions, countdown, file naming
  ScreenRecorder.swift                ScreenCaptureKit + microphone → AVAssetWriter
  CameraOverlayController.swift       Floating circular camera bubble
  Permissions.swift                   Camera / mic / screen permission helpers
```

## Roadmap

- Upload finished recordings to Google Drive and copy a share link.

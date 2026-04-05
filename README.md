# HomeonTV

HomeonTV is a SwiftUI tvOS app for browsing and controlling HomeKit homes from Apple TV.

## Features

- Dashboard for homes, rooms, and accessory reachability
- Quick controls for switches, lights, fans, speakers, and other common HomeKit characteristics
- Detailed accessory views for brightness, volume, mute, color, and temperature controls
- HomeKit camera live view and snapshot support
- Optional external RTSP camera tiles configured locally on-device

## Requirements

- Apple TV running tvOS 17 or later
- A HomeKit home configured in Apple's Home app
- iCloud Home enabled on the Apple TV
- Xcode 26.4 or later for development

## Build

1. Open `/Users/vikonmac/HomeMini/HomeMini/HomeMini/HomeonTV.xcodeproj` in Xcode.
2. Select the `HomeonTV` scheme.
3. Build and run on a physical Apple TV.

The tvOS simulator does not provide real HomeKit home data, so hardware testing is required for normal app behavior.

## Privacy

HomeKit access is requested at launch so the app can read homes, rooms, accessories, and cameras.

External RTSP stream URLs are entered manually in the app and stored locally with `@AppStorage`. This repository does not include any personal camera endpoints or credentials.

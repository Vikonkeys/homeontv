# HomeonTV

![CI](https://github.com/Vikonkeys/homeontv/actions/workflows/ci.yml/badge.svg)

HomeonTV is a SwiftUI tvOS app for browsing and controlling your HomeKit home from Apple TV.

## Why It Exists

Apple TV is a natural place for a shared home dashboard, but HomeKit control surfaces on tvOS are limited. HomeonTV is a focused companion app that makes it easier to browse rooms, inspect accessory state, and control common HomeKit devices from the big screen.

## Features

- Home dashboard with room, accessory, and online-status summaries
- Room-by-room browsing with fast navigation
- Accessory controls for switches, lights, speakers, fans, and related HomeKit characteristics
- Detail screens for brightness, volume, mute, hue, saturation, and color temperature
- HomeKit camera live view and snapshot support
- Optional external RTSP camera tiles configured locally on-device

## Requirements

- Apple TV running tvOS 17 or later
- A HomeKit home configured in Apple's Home app
- iCloud Home enabled on the Apple TV
- Xcode 26.4 or later for development

## Quick Start

1. Open `HomeonTV.xcodeproj` in Xcode.
2. Select the `HomeonTV` scheme.
3. Choose a physical Apple TV as the run destination.
4. Build and run.
5. Accept the HomeKit permission prompt on first launch.

The tvOS simulator does not expose real HomeKit home data, so normal testing should be done on hardware.

## HomeKit Setup Notes

If the app opens without homes or accessories:

1. Sign in to iCloud on Apple TV with the same Apple ID used for Home.
2. In `Settings > Users and Accounts > iCloud`, make sure Home is enabled.
3. Confirm your home is already configured in Apple's Home app on iPhone or iPad.
4. Relaunch HomeonTV and accept HomeKit access.

## Privacy

HomeonTV requests HomeKit access so it can read homes, rooms, accessories, and cameras.

External RTSP stream URLs are entered manually in the app and stored locally with `@AppStorage`. This repository does not contain personal camera endpoints, credentials, or home network configuration.

## Current Limitations

- Designed for personal and small shared-home setups first
- Requires a physical Apple TV for realistic testing
- Does not include cloud relay or remote camera credential management
- External camera playback depends on user-supplied local RTSP sources

## Development

The repository includes a GitHub Actions workflow that validates the tvOS build on pushes and pull requests.

Local validation:

```bash
xcodebuild -project HomeonTV.xcodeproj -scheme HomeonTV -configuration Debug -destination 'generic/platform=tvOS' CODE_SIGNING_ALLOWED=NO build
```

## Contributing

Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

For security-sensitive issues, follow [SECURITY.md](SECURITY.md) instead of posting details publicly.

## License

HomeonTV is released under the MIT License. See [LICENSE](LICENSE).

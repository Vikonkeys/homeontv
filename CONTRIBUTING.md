# Contributing

Thanks for contributing to HomeonTV.

## Before You Start

- Open an issue for larger changes so the approach can be aligned early
- Keep pull requests focused and easy to review
- Do not include personal HomeKit data, camera URLs, credentials, or screenshots with sensitive home details

## Development Notes

- Use Xcode 26.4 or later
- Test on a physical Apple TV when behavior depends on HomeKit data
- Keep the public repository free of local-only artifacts such as `xcuserdata`, `DerivedData`, and `.DS_Store`

## Local Validation

Run this before opening a pull request:

```bash
xcodebuild -project HomeonTV.xcodeproj -scheme HomeonTV -configuration Debug -destination 'generic/platform=tvOS' CODE_SIGNING_ALLOWED=NO build
```

## Pull Requests

- Describe what changed and why
- Mention any setup or device assumptions
- Include validation details
- Keep docs updated when behavior or setup changes

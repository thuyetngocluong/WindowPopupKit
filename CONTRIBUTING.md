# Contributing to WindowPopupKit

Thanks for your interest in improving WindowPopupKit! Contributions of all
kinds are welcome — bug reports, fixes, docs, and features.

## Getting started

1. Fork and clone the repository.
2. Open `Package.swift` in Xcode (16+), or open `Example/Example.xcodeproj`
   to work against the demo app.

WindowPopupKit is an **iOS / UIKit** package, so `swift build` on macOS does not
work (UIKit isn't available on the host). Build and test through Xcode, or with
`xcodebuild` against an iOS destination:

```bash
# Build the library for iOS
xcodebuild -scheme WindowPopupKit -destination 'generic/platform=iOS' build

# Run the unit tests on a simulator
xcodebuild -scheme WindowPopupKit -destination 'platform=iOS Simulator,name=iPhone 16' test
```

## Guidelines

- **Keep it dependency-free.** WindowPopupKit intentionally ships with zero
  third-party dependencies. Please don't add one without opening an issue to
  discuss it first.
- **Match the existing style.** Follow the conventions already in the code:
  the `WP` prefix for public types, `MARK:` section comments, and the
  configuration / presets layout under `Sources/WindowPopupKit/Configuration`.
- **Public API is documented.** Add doc comments to new public types and
  methods.
- **Add tests** for new value-type logic where practical
  (see `Tests/WindowPopupKitTests`).
- **Mind the safe area.** Interactive elements in example/demo content must stay
  inside the safe area (away from the Dynamic Island, status bar and home
  indicator).

## Pull requests

1. Create a topic branch from `main` (e.g. `fix/sheet-drag-threshold`).
2. Make your change with focused commits.
3. Ensure the build and tests pass (`xcodebuild … test`).
4. Open a PR describing **what** changed and **why**, with before/after notes
   or screenshots for any visual change.

## Reporting bugs

Open an issue using the bug report template and include a minimal reproduction,
the iOS version, and the device/simulator you saw it on. The smaller the repro,
the faster the fix.

By contributing, you agree that your contributions are licensed under the
[MIT License](LICENSE).

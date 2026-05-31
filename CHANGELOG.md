# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-06-01

### Added

- First stable public release.
- `WPPopup` engine presenting SwiftUI, `UIViewController`, or `UIView` content
  in a dedicated pass-through `UIWindow` with automatic level stacking.
- `async/await` presentation that returns the user's result, plus a
  fire-and-forget `showPopup(...) -> WPPopupDismissAction` variant.
- Presets: `toast`, `popup`, `sheet`, `loading`, `modal`, `fullScreen`, and
  `defaultPopup(at:)`.
- `WPToast` and `WPLoading` convenience layers.
- `wpPopupDismiss` on `UIView` / `UIViewController` to dismiss (optionally with a
  return value) from within UIKit content.
- Rich `WPPopupConfiguration`: position, size constraints, screen/content
  interaction, scroll-to-dismiss, background, shadow, rounded corners, border,
  entrance/exit animations, haptics, and lifecycle hooks.
- Zero third-party dependencies (pure UIKit + SwiftUI).

[Unreleased]: https://github.com/thuyetngocluong/WindowPopupKit/compare/1.0.0...HEAD
[1.0.0]: https://github.com/thuyetngocluong/WindowPopupKit/releases/tag/1.0.0

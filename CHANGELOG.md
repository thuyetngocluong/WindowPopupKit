# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Mac Catalyst support (`.macCatalyst(.v16)`); the example app builds for
  "My Mac (Mac Catalyst)".
- `WPPopupConfiguration.windowScene` to present a popup in a specific scene
  when the app has several windows on screen. A scene that is no longer
  connected when the popup is shown is ignored, and the popup goes to the
  window it would have been given without one.
- `WPPopup.startTrackingActiveWindow()` to start recording the window the user
  was last in at launch rather than with the first popup. The record follows
  the window that last took focus (iOS 17 and later) and the last touch;
  touches are watched by a gesture recognizer added to each window, which only
  observes them and never recognizes, cancels or delays them.
- An "Open another window" row in the example app (iPad and Mac).
- `PositionConstraints.topInsetFromSafeArea` to stretch a bottom-anchored popup
  up to a line below the safe area, so its height follows the window.
- A "Modal" row in the example app.

### Changed

- `defaultModal` no longer captures a height from the screen the first time it
  is read; it now sits 59 pt below the top safe-area inset and follows the
  window through resizes, rotation and an iPhone Duo fold. On a Dynamic Island
  iPhone in portrait the result is within a few points of before; in landscape,
  on iPad and on windows without a top inset the gap differs from 1.0.0.
- `defaultToast` keeps an 8 pt margin from the top edge of windows where
  nothing covers it. Hosted SwiftUI toasts do not move where the safe area is
  taller than that.
- A popup sized by `.intrinsic`, `.constant` or `.ratio` is centered in the
  safe area rather than the window, and kept inside the window; the two only
  differ when the horizontal insets are asymmetric. `.fill(padding:)` is
  unchanged.
- With several scenes connected, a popup is presented in a foreground window:
  the one that has focus, or when none has (a Mac app that is not frontmost)
  the one the user was last in. 1.0.0 took whichever scene happened
  to be listed first, which could be one in the background, leaving the popup
  invisible.

### Fixed

- Popups no longer slide under the window controls of a windowed iPad scene,
  and on a display with rounded corners but no top inset (iPhone Duo) content
  at the top starts clear of the corners. The popup's window adopts the
  corner-adapted safe area (iOS 26+): about 43 pt more at the top of an iPad
  window, 17 pt on iPhone Duo, nothing on an iPhone with a Dynamic Island in portrait.
- The entrance animation measured its off-screen start before the popup had
  been laid out in its window, so in a windowed iPad scene a toast began its
  slide partly on screen. Layout is now settled first.
- A popup animated with a custom `Animation.anchorPoint` stayed displaced by
  part of its own size when the window was resized, rotated or folded during
  the animation. The anchor is now part of the transform and the layer's
  anchor point is left alone.
- `PositionConstraints.SafeArea` now takes effect. In 1.0.0 the inset behind
  `overridesTop` / `overridesBottom` was read before the popup reached a window
  and so was always zero: every popup was anchored to the window edge whatever
  the flags said. A `.top` / `.bottom` popup is now anchored to the safe-area
  layout guide unless the matching flag is set.

  **Behaviour change:** a custom `.top` or `.bottom` configuration that leaves
  the flags at their default moves inside the safe area — a bottom popup sits
  above the home indicator instead of reaching the window edge, and a top
  popup's own background no longer runs under the status bar. Set
  `overridesBottom` / `overridesTop` to `true` to keep the 1.0.0 look. The
  presets are unaffected: `defaultSheet` and `defaultModal` set
  `overridesBottom`, `defaultToast` sets `overridesTop`, and a full-screen
  popup or a `.fill` height always spans the window.

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

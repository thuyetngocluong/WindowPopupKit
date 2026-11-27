# Windows, safe areas and platforms

A popup is laid out with Auto Layout constraints against its own window. Nothing
is measured from the screen, so a popup follows its window while that window
resizes, rotates or folds. The rules here keep your own code from undoing that.

Contents: [What changes under the app](#what-changes-under-the-app) ·
[Safe area](#safe-area) · [Sizing that survives a resize](#sizing-that-survives-a-resize) ·
[Several windows](#several-windows) · [Keyboard input](#keyboard-input) ·
[Mac Catalyst](#mac-catalyst) · [When a popup is in the wrong place](#when-a-popup-is-in-the-wrong-place)

## What changes under the app

| Where | What the window does | What covers its edges |
|---|---|---|
| iPhone | rotates | status bar or Dynamic Island at the top, home indicator at the bottom; in landscape the insets move to the sides |
| iPhone Duo (foldable) | changes size when the device folds or unfolds, while the app runs | the status bar is a vertical strip on the **trailing** edge, so the horizontal insets are unequal and the top inset is zero; the display corners are rounded |
| iPad | is resized freely, shares the screen with other apps, can be one of several windows of the same app | in a windowed scene, the close / minimise / full-screen controls sit over the top-leading corner of the content |
| Mac Catalyst | is resized freely, several windows are normal, the app is often not frontmost | the title bar |

Two habits follow. Never assume the insets are symmetric: center on the safe
area, not on the window's width. Never assume the top inset is non-zero or that
an inset of zero means the edge is free.

## Safe area

The popup window reports a safe area that includes what the plain one leaves
out: the window controls of a windowed iPad scene and the rounded corners of a
display with no top inset. Content that respects the safe area is clear of all
of it without knowing which platform it is on. This needs iOS 26 or later at run
time and Xcode 26 or later at build time; an app built with an older Xcode gets
the plain safe area, and a top popup can then sit under the iPad window
controls.

**SwiftUI content** is hosted in a `UIHostingController` and respects that safe
area on its own. Keep it that way:

```swift
import SwiftUI
import WindowPopupKit

struct WelcomeCover: View {
    @Environment(\.wpPopupDismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(colors: [.purple, .indigo], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()               // decorative: runs to every edge
                .allowsHitTesting(false)

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title) }
                }
                Spacer()
            }
            .padding()                           // interactive: stays inside the safe area
        }
    }
}
```

Putting `.ignoresSafeArea()` on the outer `ZStack` instead would pull the close
button under the Dynamic Island, the iPad window controls or the Duo's status
strip, where it may not receive touches at all.

**`UIView` / `UIViewController` content** gets no such help: it is pinned to the
popup's edges. Constrain what matters to `safeAreaLayoutGuide`, and center on it
horizontally:

```swift
import UIKit

final class NoticeView: UIView {
    init() {
        super.init(frame: .zero)
        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor),
            card.centerXAnchor.constraint(equalTo: safeAreaLayoutGuide.centerXAnchor),
            card.widthAnchor.constraint(equalToConstant: 260),
            card.heightAnchor.constraint(equalToConstant: 120)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
```

### Where a `.top` or `.bottom` popup's edge sits

By default the edge sits on the safe-area boundary: below the status bar, above
the home indicator. `positionConstraints.safeArea.overridesTop` /
`overridesBottom` move it to the window's edge instead.

| Goal | Setting | Who keeps content clear of the bar |
|---|---|---|
| A floating card near the top or bottom | default (`false`) | the library |
| A sheet whose surface reaches the bottom of the window, under the home indicator | `overridesBottom = true` (already set by `.defaultSheet`, `.defaultModal`) | SwiftUI content, automatically. Give the content a background; a SwiftUI background extends under the indicator on its own |
| A toast that hugs the top of windows where nothing covers it | `overridesTop = true` (already set by `.defaultToast`) | SwiftUI content, automatically |
| Either flag with `UIView` / `UIViewController` content | avoid, or constrain the content to `safeAreaLayoutGuide` | you. The content would otherwise land under the bar |

## Sizing that survives a resize

Give sizes as a relation to the window and they stay right:

```swift
var config = WPPopupConfiguration.defaultSheet
config.positionConstraints.height = .ratio(0.7)          // of the window, now and after any resize

var modal = WPPopupConfiguration.defaultModal            // height derived from the window through topInsetFromSafeArea
modal.positionConstraints.topInsetFromSafeArea = 24
```

What breaks it:

- `UIScreen.main.bounds`, or any size read once and stored. On iPad and Mac the
  window is not the screen; on iPhone Duo the window changes while the popup is
  up.
- `.constant` heights computed from the device (`screenHeight * 0.7`). Use
  `.ratio(0.7)`.
- Branching on `UIDevice.current.userInterfaceIdiom` or the interface orientation
  to choose a size. Branch on nothing; if a layout truly needs two forms, use the
  size class of the view in question.
- A fixed `verticalOffset` chosen to "clear the notch". The safe area already
  does that, on every device.

In SwiftUI content, prefer `frame(maxWidth:)`, padding and `ViewThatFits` over
`GeometryReader` arithmetic on the screen. A sheet spans the window's width, so
on a wide iPad or Mac window give its content a readable column:
`.frame(maxWidth: 640)` on the content, then `.frame(maxWidth: .infinity)` and
the background around it.

## Several windows

An app can have more than one window on screen: iPad multitasking and Stage
Manager, and any Mac Catalyst app.

Without instructions, a popup goes to a foreground window in this order of
preference: the one that has focus; when none has (a Mac app that is not
frontmost), the one the user was last in, meaning the window that last had focus
(iOS 17 and later) or was last touched or clicked.

That is the right window for anything the user triggers, so the usual code needs
nothing extra. Two additions for a multi-window app:

```swift
import SwiftUI
import WindowPopupKit

@main
struct DemoApp: App {
    init() {
        // The record of where the user was otherwise starts with the first popup.
        WPPopup.shared.startTrackingActiveWindow()
    }

    var body: some Scene {
        WindowGroup { Text("Content") }
    }
}
```

and, for a popup that belongs to one particular window whatever the user is
doing now (the result of a long task started in that window), name the scene:

```swift
var config = WPPopupConfiguration.defaultPopup
config.windowScene = view.window?.windowScene
```

- From UIKit the scene is `view.window?.windowScene`. In SwiftUI there is no
  environment value for it; `recipes.md` has a small reader view.
- Capture the scene when the work starts, not when it ends: by then the user may
  be in another window.
- The scene is held weakly. If its window has been closed by the time the popup
  is shown, the popup goes to the automatically chosen window instead. If a
  popup must not appear anywhere else, check `scene.activationState != .unattached`
  yourself and skip it.
- Do not pick a scene from `UIApplication.shared.connectedScenes.first`,
  `UIApplication.shared.windows` or `keyWindow`. `connectedScenes` is an
  unordered set, and every scene has a key window of its own, so both pick a
  window more or less at random. That is the bug the library's own selection
  exists to avoid.

## Keyboard input

A popup's window does not become key by default, so the app underneath keeps
keyboard focus and a text field inside the popup does not get the keyboard. For
content with text input:

```swift
var config = WPPopupConfiguration.defaultFullScreen
config.becomeKeyWindow = true
```

`becomeKeyWindow` requires a full-screen popup (the library asserts otherwise in
debug builds): a pass-through window that only partly covers the app cannot
sensibly own the keyboard while touches around it go elsewhere. Draw the dialog
you want inside the full-screen content, with its own dimmed background. The
previous key window is restored on dismiss.

## Mac Catalyst

The package supports Mac Catalyst 16 (macOS 13) and later. Nothing in the API
differs. What does:

- Several windows are the normal case. Call `startTrackingActiveWindow()` at
  launch.
- The app is often not frontmost when background work finishes. A popup shown
  then goes to the window the user was last in; set `windowScene` when it must
  be a specific one.
- The title bar is part of the safe area, so top-anchored popups sit below it.
- Haptics do nothing on a Mac; do not rely on `hapticFeedback` as the only
  signal.
- Pointer clicks arrive as touches, so tap-to-dismiss and drag-to-dismiss work
  with a mouse or trackpad.

## When a popup is in the wrong place

| Symptom | Likely cause | Fix |
|---|---|---|
| Disappears after about two seconds | bare `WPPopupConfiguration()` (the default of `show(configuration:)` and `showPopup(...)`) | start from a preset, or set `displayDuration = .infinity` |
| A button near the top does not respond | the content ignores the safe area and the button is under a bar or window controls | `.ignoresSafeArea()` on the background only; constrain UIKit content to `safeAreaLayoutGuide` |
| Sits under the Dynamic Island or status bar | `overridesTop` with UIKit content, or a `.custom` point chosen by hand | turn the flag off; use `.top` with a `verticalOffset` |
| Off-center on iPhone Duo | content centered on the window's width | center on the safe area (`safeAreaLayoutGuide.centerXAnchor`); SwiftUI content does this already |
| Wrong height after rotation, a window resize or a fold | a size computed from the screen | `.ratio`, `.fill` or `topInsetFromSafeArea` |
| Appears in another window | a scene picked by hand, or a background-task popup with no `windowScene` | remove the manual lookup; set `windowScene` from the triggering view |
| Text field never gets the keyboard | popup is not the key window | `.defaultFullScreen` plus `becomeKeyWindow = true` |
| Nothing appears at all | called before any scene is connected (too early at launch) | present after the first scene is active |
| The app is frozen behind a spinner | `dismissLoading()` skipped on an error path | `defer { WPLoading.dismissLoading() }` |

---
name: window-popup-kit
description: >-
  Add toasts, banners, popups, confirmation dialogs that return the user's
  choice, bottom sheets, modals, blocking loading overlays and full-screen
  covers to an iOS, iPadOS, iPhone Duo or Mac Catalyst app with the
  WindowPopupKit Swift package (WPPopup, WPToast, WPLoading,
  WPPopupConfiguration). Use this skill whenever a project imports
  WindowPopupKit or lists it as a dependency and the task touches overlay UI of
  any kind: showing a toast or a spinner, asking the user to confirm something,
  presenting a sheet, awaiting a result, presenting from a view model or from
  UIKit code. Use it too when the user asks to add WindowPopupKit to a project,
  and when a popup made with it is misplaced, clipped by a status bar or window
  controls, sized wrong after a rotation, window resize or fold, disappears on
  its own, or shows up in the wrong window on iPad or Mac, even if the user only
  says "show a toast" or "add a confirm dialog".
---

# WindowPopupKit

WindowPopupKit shows every popup in its own pass-through `UIWindow` above the
app. Two consequences shape everything below:

- A popup needs no place in the view tree. Call it from a button action, a view
  model or a view controller; there is no `isPresented` binding to thread
  through.
- Presenting is `async`. `await` returns when the popup has gone, with the value
  the content dismissed it with, so a confirmation reads as straight-line code.

Reference files, read when the task needs them:

- `references/recipes.md`: complete, compiling examples for each shape. Start
  here when writing new code.
- `references/configuration.md`: every field of `WPPopupConfiguration`, its
  default, and what each preset sets.
- `references/platforms.md`: resizable windows, iPhone Duo, iPad windows, Mac
  Catalyst, safe areas, several windows, keyboard input. Read it before touching
  layout, or when a popup is in the wrong place.

## 1. Check the dependency first

Look for `WindowPopupKit` in `Package.swift`, or for an
`XCRemoteSwiftPackageReference` to it in `project.pbxproj`. If it is missing,
add it rather than writing code that cannot compile:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/thuyetngocluong/WindowPopupKit.git", from: "1.0.0")
],
targets: [
    .target(name: "App", dependencies: ["WindowPopupKit"])
]
```

In an Xcode project the package is added through the project file; if you cannot
edit it reliably, tell the user to add the package in Xcode (File, Add Package
Dependencies) and continue with the code.

Requirements: iOS / iPadOS 16, Mac Catalyst 16. The package is UIKit code, so
`swift build` on a Mac does not compile it; build for an iOS or Mac Catalyst
destination.

**Which version the project resolved matters.** This skill describes the
package as of the commit it ships with. Release 1.0.0 predates part of it, and
until a later release is tagged, `from: "1.0.0"` resolves to exactly 1.0.0.
Check `Package.resolved`, or look for `startTrackingActiveWindow` in the package
checkout. On 1.0.0:

- these do not exist and will not compile: `WPPopupConfiguration.windowScene`,
  `WPPopup.startTrackingActiveWindow()`,
  `PositionConstraints.topInsetFromSafeArea`, the Mac Catalyst platform;
- these compile but behave differently: a popup goes to whichever scene is
  listed first rather than the focused window; `.defaultModal` has a height
  captured from the screen once instead of following the window; popups are
  centered on the window rather than the safe area; `SafeArea.overridesTop` /
  `overridesBottom` have no effect.

When the task needs any of that and the project is on 1.0.0, say so and let the
user choose: a later release if one exists by then, or a dependency on the
`master` branch or a specific revision. Do not change their version pin on your
own.

## 2. Pick the shape

| The user wants | Call | Notes |
|---|---|---|
| A short message that goes away | `WPToast.show(.success, message: "Saved")` | `.success` `.error` `.warning` `.info` `.network`, or your own identifier. Callable from any thread. |
| A blocking spinner around work | `WPLoading.showLoading()` … `WPLoading.dismissLoading()` | One at a time; main actor only. |
| A dialog, with or without an answer | `await WPPopup.shared.popup { … }` | Centered, dimmed; a tap above or below it dismisses. |
| A bottom sheet | `await WPPopup.shared.sheet { … }` | Height from content; drag down to dismiss. |
| A tall modal with a strip of background above | `await WPPopup.shared.show(configuration: .defaultModal) { … }` | Height follows the window. |
| A full-screen cover | `await WPPopup.shared.fullScreen { … }` | The only shape that can take keyboard input, and only with `becomeKeyWindow = true` (rule below). |
| Something else | start from the nearest preset, change fields, `await WPPopup.shared.show(configuration:) { … }` | See `references/configuration.md`. |
| A handle to dismiss later, no awaiting | `WPPopup.shared.showPopup(swiftUIView:configuration:)` | Returns a `WPPopupDismissAction`; call it to dismiss. |
| `UIView` / `UIViewController` content | `WPPopup.shared.showPopup(view:configuration:)` / `showPopup(viewController:configuration:)` | Same engine. To wait for it, declare the result type (rule below). |

All of `WPPopup` and `WPLoading` is `@MainActor`. From a background context hop
first (`await MainActor.run { … }` or a `@MainActor` function).

## 3. Write the content and dismiss it

SwiftUI content reads the dismiss action from the environment. Calling it closes
the popup; the argument, if any, becomes the value the `await` returns.

```swift
import SwiftUI
import WindowPopupKit

enum DeleteChoice: Sendable { case delete, cancel }

struct ConfirmDeleteView: View {
    @Environment(\.wpPopupDismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Delete this item?").font(.headline)
            HStack(spacing: 12) {
                Button("Cancel") { dismiss(DeleteChoice.cancel) }
                Button("Delete", role: .destructive) { dismiss(DeleteChoice.delete) }
            }
        }
        .padding(24)
        .frame(maxWidth: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 32)
    }
}

@MainActor
func confirmDelete() async -> Bool {
    let choice = await WPPopup.shared.popup { ConfirmDeleteView() } as? DeleteChoice
    return choice == .delete
}
```

Every file that touches the API needs `import WindowPopupKit`, including a view
file whose only use of it is `@Environment(\.wpPopupDismiss)`. Without the
import the file may still compile through another file's import, with a warning
that newer compilers turn into an error.

Three things to get right here:

- **The result is `(any Sendable)?`, and `nil` is a real outcome.** `nil` means
  nobody supplied a value: a tap outside, a drag, the timer, `dismiss()` with no
  argument, a value of another type than a typed `showPopup` asked for, or no
  window scene to present in (the call then returns at once and nothing is
  shown). Treat `nil` as "no decision", which almost always means cancel. Never
  force-cast the result.
- **The surface comes from your content.** The card, its background, its corner
  radius and its margins are yours to draw, as above; a preset decides position,
  dimming, touch handling and animation. Two presets add a little:
  `.defaultSheet` and `.defaultModal` clip their top corners to 16 pt, and
  `.defaultModal` also fills itself with `systemBackground`. A sheet built on
  `.defaultSheet` with no background of its own is see-through.
- **UIKit content** reaches the same action through `view.wpPopupDismiss?(value)`
  or `viewController.wpPopupDismiss?(value)`. It is `nil` until the view is
  inside the popup's window, so call it from an action, not from `init`.

## 4. Rules that prevent the usual mistakes

**Start from a preset.** A bare `WPPopupConfiguration()` closes itself after two
seconds, has no dimming and dismisses on any outside tap, and it is the default
of `show(configuration:)` and of every `showPopup(...)`. Code that passes no
configuration to those gets a popup that vanishes while the user is reading it.
Pass `.defaultPopup`, `.defaultSheet`, … and adjust from there.

```swift
var config = WPPopupConfiguration.defaultPopup
config.screenInteraction = .absorbTouches        // the user must answer
config.hapticFeedback = .warning
let handle = WPPopup.shared.showPopup(swiftUIView: ConfirmDeleteView(), configuration: config)
```

**`showPopup` waits only when its result has a type.** Each `showPopup` exists
twice with the same arguments: one returns a dismiss handle immediately, the
other waits for the popup to close and returns a typed value. Swift picks the
waiting one only if the result's type is declared. `await
WPPopup.shared.showPopup(…)` on its own compiles, with just a "no 'async'
operations occur within 'await'" warning, and does not wait, so whatever follows
runs while the popup is still on screen.

```swift
let rated: Bool? = await WPPopup.shared.showPopup(view: view, configuration: .defaultPopup)   // waits
let _: Bool? = await WPPopup.shared.showPopup(view: view, configuration: .defaultPopup)       // waits, value unused
```

`popup`, `sheet`, `fullScreen` and `show(configuration:)` take SwiftUI content
and always wait.

**Do not measure the screen.** Never size or place a popup from `UIScreen.main`,
a window's bounds captured once, the interface orientation or the device idiom.
The window resizes under the app on iPad and Mac, rotates, and folds on iPhone
Duo; a number read once is wrong a moment later. Express size relative to the
window and let the constraints follow it:

```swift
var sheet = WPPopupConfiguration.defaultSheet
sheet.positionConstraints.height = .ratio(0.7)     // 70% of the window, whatever its size

var card = WPPopupConfiguration.defaultPopup
card.positionConstraints.width = .ratio(0.9)       // 90% of the window's width
```

**Keep controls inside the safe area.** Let decorative backgrounds run to the
edge and keep everything tappable inside. In SwiftUI that means
`.ignoresSafeArea()` on the background layer only, never on the view that holds
the buttons. `UIView` / `UIViewController` content must constrain to
`safeAreaLayoutGuide` itself. `references/platforms.md` explains what the safe
area covers on each platform and how the `overridesTop` / `overridesBottom`
flags move a popup's edge.

**Text input needs a full-screen, key-window popup.** A popup does not take
keyboard focus by default, so a `TextField` in a plain popup or sheet does not
get the keyboard. Start from `.defaultFullScreen`, set `becomeKeyWindow = true`, and draw the
dialog inside that full-screen content. The library asserts in debug builds if
`becomeKeyWindow` is set on anything that is not full screen.

**Pair every `showLoading` with a `dismissLoading` on every path.** The overlay
blocks all touches until it is dismissed, so an early `return` or a thrown error
that skips the dismiss freezes the app. `defer` makes it hard to get wrong:

```swift
@MainActor
func save(_ work: () async throws -> Void) async {
    WPLoading.showLoading()
    defer { WPLoading.dismissLoading() }
    do {
        try await work()
        WPToast.show(.success, message: "Saved")
    } catch {
        WPToast.show(.error, message: error.localizedDescription)
    }
}
```

**Let the library pick the window; do not pick one yourself.** In an app with
several windows (iPad multitasking, Stage Manager, Mac) a popup goes to the
window that has focus, which is the one the user just acted in. Do not look a
scene up through `UIApplication.shared.connectedScenes.first` or `windows.first`:
that order is arbitrary and is how popups end up in a background window. Two
things are worth doing in a multi-window app:

```swift
WPPopup.shared.startTrackingActiveWindow()     // once at launch, on the main actor

var config = WPPopupConfiguration.defaultSheet
config.windowScene = view.window?.windowScene  // only for a popup tied to one window,
                                               // e.g. the result of that window's background task
```

## 5. Verify

- Build the app target for an iOS Simulator (and for Mac Catalyst if the app
  supports it) with the project's usual build command or tool.
- If you can run the app, look at the result rather than trusting the code: the
  popup is where it should be, nothing tappable sits under a status bar, a
  Dynamic Island, window controls or the home indicator, and every button
  actually fires.
- For layout work, check more than one window shape: both orientations, a resized
  iPad window, and an iPhone Duo folded and unfolded where a simulator is
  available.
- Check the paths that end without a choice: tap outside, drag away, let a timed
  popup expire. The code after the `await` must cope with `nil`.

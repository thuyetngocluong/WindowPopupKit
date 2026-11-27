# WPPopupConfiguration reference

`WPPopupConfiguration` is a struct. Copy a preset into a `var`, change fields,
pass it to `WPPopup.shared.show(configuration:)` or to any other entry point.

Contents: [Presets](#presets) · [Layout](#layout) · [Interaction](#interaction) ·
[Appearance](#appearance) · [Animation](#animation) · [Window](#window) ·
[Feedback and lifecycle](#feedback-and-lifecycle) · [App-wide defaults](#app-wide-defaults)

## Presets

| Preset | Position | Closes itself | Tap outside | Tap on content | Drag to dismiss | Dimming |
|---|---|---|---|---|---|---|
| `WPPopupConfiguration()` | center | after 2 s | dismisses | absorbed | no | none |
| `.defaultToast` | top | after 2 s | passes through to the app | dismisses | yes | none |
| `.defaultPopup` | center | never | dismisses | absorbed | no | black 50% |
| `.defaultPopup(at: point)` | centered on `point` | never | dismisses | absorbed | no | black 50% |
| `.defaultLoading` | center | never | absorbed | absorbed | no | black 30% |
| `.defaultSheet` | bottom | never | absorbed | absorbed | yes | black 30% |
| `.defaultModal` | bottom, top edge 59 pt below the safe area | never | absorbed | absorbed | yes | black 30% |
| `.defaultFullScreen` | fills the window | never | absorbed | absorbed | no | none |

Things the table implies that are easy to miss:

- `.defaultSheet` and `.defaultModal` do **not** close on an outside tap. Give
  the content a close control, or set `screenInteraction = .dismiss`.
- `.defaultPopup` **does** close on an outside tap and then returns `nil`. For a
  question the user must answer, set `screenInteraction = .absorbTouches`.
- "Outside" means outside the popup's frame, not outside the card you drew. The
  default width is `.fill(padding: 0)`, so the frame spans the window at the
  content's height, and a tap beside a narrower card, level with it, is absorbed
  rather than dismissing. Set `positionConstraints.width = .intrinsic` to make
  the frame hug the content.
- `.defaultToast` lets touches outside the toast reach the app, so the app stays
  usable while a toast is up.
- `.defaultSheet` rounds its top corners (16 pt) but has a clear content
  background: the sheet's surface comes from your content. `.defaultModal` adds
  `contentBackground = .color(.systemBackground)`.
- The convenience methods use these presets: `toast` → `.defaultToast`, `popup`
  → `.defaultPopup`, `sheet` → `.defaultSheet`, `fullScreen` →
  `.defaultFullScreen`. `show(configuration:)` and every `showPopup(...)` default
  to the bare `WPPopupConfiguration()` in the first row.

## Layout

```swift
var config = WPPopupConfiguration.defaultPopup
config.position = .top                                   // .top | .center | .bottom | .custom(CGPoint)
config.positionConstraints.width = .fill(padding: 16)    // .intrinsic | .constant(pt) | .ratio(0...1) | .fill(padding:)
config.positionConstraints.maxWidth = .constant(480)     // a cap: never wider than this
config.positionConstraints.height = .intrinsic
config.positionConstraints.maxHeight = .ratio(0.8)       // a cap: never taller than 80% of the window
config.positionConstraints.verticalOffset = 8            // away from the anchored edge; shifts a centered popup down
config.displayDuration = .seconds(3)                     // or .infinity
```

- **`position`**: `.top` and `.bottom` anchor that edge to the safe area;
  `.center` centers in the window vertically; `.custom(point)` puts the popup's
  center on `point`, in the window's coordinate space (UIKit:
  `view.convert(point, to: nil)`; SwiftUI: the `.global` space when the hosting
  view fills its window).
- **`width` / `height`**: `.ratio` and `.fill` are measured against the window,
  so they follow it through every resize. `.intrinsic` takes the content's own
  size. Defaults: `width = .fill(padding: 0)`, `height = .intrinsic`.
- **Horizontal placement**: a popup sized by `.intrinsic`, `.constant` or
  `.ratio` is centered in the safe area and kept inside the window. `.fill`
  keeps its padding from the window's edges.
- **`maxWidth` / `maxHeight`**: caps in the same vocabulary; `.intrinsic` means
  no cap. A cap wins over the size on its axis: `.fill(padding: 0)` with
  `maxWidth = .constant(640)` fills the window up to 640 pt and beyond that is
  640 pt wide, centered in the safe area and inside its padding. A capped
  `.fill` height keeps the edge its `position` anchors (the top for `.top`, the
  bottom for `.bottom`) and stays centered for `.center`.
  **Releases up to 1.1.0 do not do this:** there a cap beside a `.fill`,
  `.ratio` or `.constant` that asks for more conflicts with it, and Auto Layout
  breaks one of the two unpredictably. On those versions use a cap only with an
  `.intrinsic` size, and keep a full-width sheet readable on a wide window by
  capping the content instead (`.frame(maxWidth: 640)` inside a
  `.frame(maxWidth: .infinity)`).
- **`topInsetFromSafeArea`**: for a `.bottom` popup with `.intrinsic` height,
  stretches the popup up until its top edge is this far below the safe area. The
  height is then derived from the window. `.defaultModal` uses 59. An explicit
  `height` wins over it; `maxHeight` still caps it.
- **`safeArea.overridesTop` / `overridesBottom`**: anchor a `.top` / `.bottom`
  popup's edge to the window instead of the safe area, so its background runs
  under the bar. See `platforms.md` for when that is right. They do nothing for
  `.center`, `.custom`, a `.fill` height or a full-screen popup.
- **`isFullScreen`** (read-only) is true for `width: .fill(padding: 0)` with
  `height: .ratio(1.0)`; that pair is what `becomeKeyWindow` requires.

## Interaction

```swift
config.screenInteraction = .absorbTouches   // touches outside the content
config.contentInteraction = .absorbTouches  // touches on the content
config.scroll = .enabled                    // drag to dismiss
```

`UserInteraction` has three cases, for both fields:

| Case | Outside the content (`screenInteraction`) | On the content (`contentInteraction`) |
|---|---|---|
| `.dismiss` | a tap closes the popup | a tap closes the popup (toasts) |
| `.absorbTouches` | nothing happens; the app underneath is blocked | the content handles its own touches normally |
| `.forward` | the touch reaches the app underneath | the content is not hit-testable: a touch on it is treated as an outside touch and handled by `screenInteraction`, so it reaches the app only when that is `.forward` too |

`Scroll` controls dragging the popup away: down for `.bottom`, up for `.top`,
and either way for `.center` and `.custom`.

- `.disabled`, `.enabled` (dismiss past half the popup's height), `.oneThird`,
  `.oneFourth`, `.oneFifth`, `.dismissAt(ratio)`.
- `.scrollOnly` lets the popup be dragged and spring back without ever
  dismissing.
- When the content contains a scroll view (the first one found is used), the
  drag is coordinated with it. A drag that starts on the scroll view scrolls it
  first and moves the popup only while the scroll view is at its top. A drag
  that starts anywhere else, on a header or a grab handle, always moves the
  popup. Dragging against the dismiss direction pulls the popup with resistance.
  **Releases up to 1.1.0** treat every drag like one on the scroll view: a
  header drag does nothing until the list is back at its top. There, give the
  content a close control rather than relying on the handle.

## Appearance

```swift
config.screenBackground = .color(.black.withAlphaComponent(0.4))   // behind the popup
config.contentBackground = .visualEffect(.systemMaterial)          // the popup's own surface
config.roundCorners = .top(20)                                     // .all(r) | .top(r) | .bottom(r) | .none
config.shadow = .default                                           // or Shadow(color:opacity:radius:offset:)
config.border = .init(color: .separator, width: 1)
config.windowInterfaceStyle = .dark                                // force light / dark for this popup
```

`BackgroundStyle`: `.clear`, `.color(UIColor)`, `.gradient(colors:startPoint:endPoint:)`,
`.visualEffect(UIBlurEffect.Style)`, `.image(UIImage)`.

`roundCorners` clips the popup's container. A `shadow` on a clipped view does
not show, so when both are set the container stops clipping; round the content
yourself in that case.

## Animation

```swift
config.entranceAnimation = .scaleAndFade      // .none | .translation | .fade | .scaleAndFade
config.exitAnimation = .init(duration: 0.25, fade: .init(from: 1, to: 0))
config.entranceAnimation = .init(
    duration: 0.4,
    spring: .init(damping: 0.8, initialVelocity: 0.5),
    translate: .init(anchor: .bottom),        // .automatic | .top | .bottom | .left | .right
    scale: .init(from: 0.9, to: 1),
    fade: .init(from: 0, to: 1),
    anchorPoint: CGPoint(x: 0.5, y: 0)        // unit point the scale grows from; nil = center
)
```

`translate` slides the popup in from, or out to, an edge; `.automatic` picks the
edge from `position`. Entrance and exit are independent. An exit animation needs
its own `from` / `to` values pointing the other way (`fade: .init(from: 1, to: 0)`).

## Window

```swift
config.becomeKeyWindow = true                 // keyboard input; full-screen popups only
config.windowScene = view.window?.windowScene // pin to one window of a multi-window app
config.overrideWindowLevel = .alert + 1       // above everything else the app shows
```

Popups stack in the order they are shown, each above the last. Set
`overrideWindowLevel` only for a popup that must sit above later ones.

## Feedback and lifecycle

```swift
config.hapticFeedback = .success   // .none | .success | .warning | .error | .light | .medium | .heavy
config.lifecycleEvents = .init(
    willAppear: { },
    didAppear: { },
    willDisappear: { },
    didDisappear: { }
)
```

The haptic fires as the popup appears. `didDisappear` runs after the exit
animation, immediately before the `await` returns. The auto-dismiss timer starts
after the entrance animation ends.

## App-wide defaults

The presets are mutable statics. Change one once at launch, on the main actor,
to restyle every popup that uses it:

```swift
WPPopupConfiguration.defaultToast.displayDuration = .seconds(3)
WPPopupConfiguration.defaultPopup.screenBackground = .color(.black.withAlphaComponent(0.35))
```

Do not mutate them later from arbitrary code: they are unsynchronized globals,
and a change made in one place silently restyles every other caller.

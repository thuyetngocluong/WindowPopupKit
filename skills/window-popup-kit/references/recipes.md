# Recipes

Complete examples, one per shape. Each compiles as written against the package
(Swift 5 and Swift 6 language modes). The import lines are left out of the
examples to keep them short; every file you put one in needs them:

```swift
import SwiftUI          // or UIKit
import WindowPopupKit   // also in a file that only reads \.wpPopupDismiss
```

Adapt the names and the content; keep the structure.

Contents: [Toasts](#toasts) · [Loading around work](#loading-around-work) ·
[A question the user must answer](#a-question-the-user-must-answer) ·
[Bottom sheet with a scrolling list](#bottom-sheet-with-a-scrolling-list) ·
[Modal](#modal) · [Full-screen cover](#full-screen-cover) ·
[A dialog with a text field](#a-dialog-with-a-text-field) ·
[A popup you dismiss from outside](#a-popup-you-dismiss-from-outside) ·
[UIKit content](#uikit-content) · [From a view model](#from-a-view-model) ·
[Custom toast and loading views](#custom-toast-and-loading-views) ·
[A popup tied to one window](#a-popup-tied-to-one-window) ·
[A popup anchored at a point](#a-popup-anchored-at-a-point)

## Toasts

```swift
func toastExamples() {
    WPToast.show(.success, message: "Saved")
    WPToast.show(.error, message: "Could not reach the server")

    // Replace whatever toasts are showing instead of stacking another one.
    WPToast.showExclusive(.warning, message: "Battery is low")

    WPToast.dismissAll()
}
```

`WPToast` is safe to call from any thread and needs no `await`. Several toasts
at once are drawn at the same spot, the newest covering the older ones, so use
`showExclusive` when a newer message makes the older ones stale. A toast closes
after two seconds, on a tap, or when dragged up.

A longer-lived or differently placed toast is a configuration away:

```swift
func bottomToast() {
    var config = WPPopupConfiguration.defaultToast
    config.position = .bottom
    config.positionConstraints.safeArea = .init()      // sit on the safe area, above the home indicator
    config.positionConstraints.verticalOffset = 12
    config.displayDuration = .seconds(4)
    WPToast.show(.info, message: "Draft restored", configuration: config)
}
```

## Loading around work

```swift
@MainActor
func withLoading<T: Sendable>(_ work: @MainActor () async throws -> T) async rethrows -> T {
    WPLoading.showLoading()
    defer { WPLoading.dismissLoading() }
    return try await work()
}

@MainActor
func refreshProfile(using load: @MainActor () async throws -> String) async {
    do {
        let name = try await withLoading { try await load() }
        WPToast.show(.success, message: "Welcome back, \(name)")
    } catch {
        WPToast.show(.error, message: error.localizedDescription)
    }
}
```

Only one loading overlay exists at a time: a second `showLoading()` replaces the
first, and one `dismissLoading()` removes it. Do not use it as a counter for
overlapping tasks; keep your own count if several tasks share the overlay.

## A question the user must answer

```swift
struct DiscardChangesView: View {
    @Environment(\.wpPopupDismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Discard your changes?").font(.headline)
            Text("This cannot be undone.").font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button("Keep editing") { dismiss(false) }
                    .buttonStyle(.bordered)
                Button("Discard", role: .destructive) { dismiss(true) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(maxWidth: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 32)
    }
}

@MainActor
func askToDiscardChanges() async -> Bool {
    var config = WPPopupConfiguration.defaultPopup
    config.screenInteraction = .absorbTouches     // a tap outside no longer dismisses
    config.hapticFeedback = .warning
    let discard: Bool? = await WPPopup.shared.showPopup(
        swiftUIView: DiscardChangesView(),
        configuration: config
    )
    return discard ?? false
}
```

The typed `showPopup` casts the dismiss value for you; a value of another type
comes back as `nil`, the same as no value. The untyped form is
`await WPPopup.shared.popup(configuration: config) { DiscardChangesView() } as? Bool`.

## Bottom sheet with a scrolling list

```swift
struct OptionSheet: View {
    let title: String
    let options: [String]
    @Environment(\.wpPopupDismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // A fixed header above the list, with a way out that needs no dragging.
            VStack(spacing: 10) {
                Capsule().fill(.secondary.opacity(0.4)).frame(width: 40, height: 5)
                HStack {
                    Text(title).font(.title3.bold())
                    Spacer()
                    Button("Close") { dismiss() }
                }
            }
            .padding()

            Divider()

            // A drag on the list moves the sheet only while the list is at its top.
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(options, id: \.self) { option in
                        Button { dismiss(option) } label: {
                            Text(option)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 640)                              // a readable column on a wide window…
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // …centered in a sheet that spans it
        .background(Color(.systemBackground))
    }
}

@MainActor
func pickOption(_ title: String, from options: [String]) async -> String? {
    var config = WPPopupConfiguration.defaultSheet
    config.positionConstraints.height = .ratio(0.7)
    return await WPPopup.shared.sheet(configuration: config) {
        OptionSheet(title: title, options: options)
    } as? String
}
```

Without an explicit `height` a sheet is as tall as its content, which is what a
short sheet wants. The sheet does not close on an outside tap, so the content
needs a way out; set `config.screenInteraction = .dismiss` to add one.

## Modal

```swift
@MainActor
func showTerms() async {
    await WPPopup.shared.show(configuration: .defaultModal) {
        OptionSheet(title: "Terms", options: ["Accept", "Decline"])
    }
}
```

`.defaultModal` stops 59 pt below the top of the safe area and takes its height
from the window, so it stays right through a rotation, a resize or a fold. Set
`positionConstraints.topInsetFromSafeArea` to change the gap.

## Full-screen cover

```swift
struct OnboardingCover: View {
    @Environment(\.wpPopupDismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.indigo
                .ignoresSafeArea()            // background only
                .allowsHitTesting(false)

            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.title)
                    }
                }
                Spacer()
                Text("Welcome").font(.largeTitle.bold())
                Spacer()
                Button("Get started") { dismiss("started") }
                    .buttonStyle(.borderedProminent)
            }
            .padding()                         // controls stay inside the safe area
            .foregroundStyle(.white)
        }
    }
}

@MainActor
func showOnboarding() async {
    await WPPopup.shared.fullScreen { OnboardingCover() }
}
```

## A dialog with a text field

Keyboard input needs a full-screen popup that becomes the key window. Draw the
dialog inside it:

```swift
struct RenameDialog: View {
    @State private var name: String
    @Environment(\.wpPopupDismiss) private var dismiss

    init(current: String) { _name = State(initialValue: current) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 16) {
                Text("Rename").font(.headline)
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                HStack(spacing: 12) {
                    Button("Cancel") { dismiss() }
                    Button("Save") { dismiss(name) }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(24)
            .frame(maxWidth: 360)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding()
        }
    }
}

@MainActor
func askForName(current: String) async -> String? {
    var config = WPPopupConfiguration.defaultFullScreen
    config.becomeKeyWindow = true
    config.entranceAnimation = .fade
    config.exitAnimation = .init(duration: 0.2, fade: .init(from: 1, to: 0))
    return await WPPopup.shared.show(configuration: config) {
        RenameDialog(current: current)
    } as? String
}
```

## A popup you dismiss from outside

The non-async `showPopup` returns a handle. Calling the handle dismisses the
popup; an optional argument becomes its return value.

```swift
@MainActor
final class UploadBanner {
    private var handle: WPPopupDismissAction?

    func show() {
        var config = WPPopupConfiguration.defaultToast
        config.displayDuration = .infinity
        config.contentInteraction = .absorbTouches     // a tap must not dismiss it
        config.scroll = .disabled
        handle = WPPopup.shared.showPopup(
            swiftUIView: Label("Uploading…", systemImage: "arrow.up.circle")
                .padding()
                .background(.regularMaterial, in: Capsule()),
            configuration: config
        )
    }

    func hide() {
        handle?()
        handle = nil
    }
}
```

`showPopup` comes in two forms that take the same arguments: this one returns
the handle at once, the other waits and returns a typed result. The compiler
picks the waiting form only when the result has a declared type. Written as
`await WPPopup.shared.showPopup(…)` with no type, the call compiles with nothing
more than a "no 'async' operations occur within 'await'" warning, returns
immediately, and the code after it runs while the popup is still up. To wait,
declare the type (`let rated: Bool? = await …`, or `let _: Bool? = await …`
when the value does not matter), or use `show(configuration:)`, `popup`, `sheet`
or `fullScreen`, which always wait.

## UIKit content

```swift
final class RatingViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let card = UIStackView()
        card.axis = .vertical
        card.spacing = 12
        card.alignment = .center
        card.isLayoutMarginsRelativeArrangement = true
        card.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = "Enjoying the app?"
        title.font = .preferredFont(forTextStyle: .headline)
        card.addArrangedSubview(title)

        for (label, value) in [("Yes", true), ("Not really", false)] {
            let button = UIButton(configuration: .bordered(), primaryAction: UIAction(title: label) { [weak self] _ in
                self?.wpPopupDismiss?(value)
            })
            card.addArrangedSubview(button)
        }

        view.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: view.topAnchor),
            card.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            // The popup spans the window; center on the safe area so an inset on
            // one side only (iPhone Duo) does not push the card off the middle.
            card.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            card.widthAnchor.constraint(equalToConstant: 260)
        ])
    }
}

@MainActor
func askForRating() async -> Bool? {
    await WPPopup.shared.showPopup(viewController: RatingViewController(), configuration: .defaultPopup)
}
```

Pass a preset explicitly: `showPopup` defaults to the bare configuration that
closes after two seconds. A plain `UIView` works the same way through
`showPopup(view:configuration:)` and `view.wpPopupDismiss?(value)`.

## From a view model

```swift
@MainActor
final class CheckoutViewModel: ObservableObject {
    @Published private(set) var isPaid = false

    func pay(_ charge: @MainActor () async throws -> Void) async {
        guard await askToDiscardChanges() == false else { return }
        WPLoading.showLoading()
        defer { WPLoading.dismissLoading() }
        do {
            try await charge()
            isPaid = true
            WPToast.show(.success, message: "Payment complete")
        } catch {
            WPToast.show(.error, message: "Payment failed")
        }
    }
}
```

No view is involved and nothing is bound: the view model presents, awaits the
answer and carries on. Keep presenting code on the main actor.

## Custom toast and loading views

Register once at launch. The factory receives the message and returns the view
for that identifier; registering a built-in identifier replaces its look.

```swift
extension WPToastIdentifier {
    static let promo: WPToastIdentifier = "promo"
}

struct PromoToast: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "gift.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.pink.gradient, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
    }
}

@MainActor
func registerPopupStyles() {
    WPToast.register(for: .promo) { message in PromoToast(text: message) }
    WPLoading.register { ProgressView().controlSize(.large).padding(28).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) }
    WPPopupConfiguration.defaultToast.displayDuration = .seconds(3)
}

func showPromo() {
    WPToast.show(.promo, message: "50% off today")
}
```

Showing an identifier nobody registered trips an assertion in debug builds and
shows nothing in release.

## A popup tied to one window

For a popup the user triggers, do nothing: it goes to the window they are in.
Name the scene only when the popup must land in one particular window later,
such as when work started there finishes. SwiftUI has no environment value for
the scene, so read it from the view hierarchy:

```swift
/// Reports the window scene the view is in. Use as a background:
/// `.background(WindowSceneReader { scene = $0 })`
struct WindowSceneReader: UIViewRepresentable {
    var onChange: @MainActor (UIWindowScene?) -> Void

    func makeUIView(context: Context) -> ReaderView { ReaderView(onChange: onChange) }
    func updateUIView(_ uiView: ReaderView, context: Context) { uiView.onChange = onChange }

    final class ReaderView: UIView {
        var onChange: @MainActor (UIWindowScene?) -> Void

        init(onChange: @escaping @MainActor (UIWindowScene?) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            let scene = window?.windowScene
            // After the current update, so SwiftUI state is not changed mid-pass.
            Task { @MainActor [weak self] in self?.onChange(scene) }
        }
    }
}

struct ExportButton: View {
    @State private var scene: UIWindowScene?
    let export: @MainActor () async -> Void

    var body: some View {
        Button("Export") {
            let startedIn = scene                      // captured when the work starts
            Task { @MainActor in
                await export()
                var config = WPPopupConfiguration.defaultToast
                config.windowScene = startedIn
                WPToast.show(.success, message: "Export finished", configuration: config)
            }
        }
        .background(WindowSceneReader { scene = $0 })
    }
}
```

From UIKit it is one line: `config.windowScene = view.window?.windowScene`.

## A popup anchored at a point

```swift
@MainActor
func showHint(over view: UIView) {
    // The point is in window coordinates; the popup's center lands on it.
    let center = view.convert(CGPoint(x: view.bounds.midX, y: view.bounds.midY), to: nil)
    var config = WPPopupConfiguration.defaultPopup(at: CGPoint(x: center.x, y: center.y - 60))
    config.screenBackground = .clear
    config.windowScene = view.window?.windowScene
    WPPopup.shared.showPopup(
        swiftUIView: Text("Tap here to start")
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)),
        configuration: config
    )
}
```

A point popup is not kept inside the window or the safe area for you. Compute
the point from a view at presentation time, as here, and prefer `.top`,
`.center` or `.bottom` when an exact spot is not the goal.

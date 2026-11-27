import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Remembers which scene the user was last in.
///
/// While one of the app's windows has focus, UIKit says which: its interface
/// is drawn as active. Once none has — a Mac app that is no longer frontmost —
/// there is nothing left to ask, and "key window" does not help: every window
/// of a Mac app can report itself key at once. So the tracker keeps a record
/// of its own, from two sources:
///
/// - the window that last became active (iOS 17 and later), which also covers
///   focus moved without a touch: the keyboard, a menu, the window switcher;
/// - the window that last received a touch, watched for with a recognizer that
///   observes touches and never takes part in gesture recognition.
@MainActor
final class WPActiveSceneTracker {

    static let shared = WPActiveSceneTracker()

    /// The scene the user was last in: the one whose window most recently took
    /// focus or received a touch, a pencil stroke or a pointer click. `nil`
    /// until either happens after `start()`.
    private(set) weak var lastInteractedScene: UIWindowScene?

    private var observers: [NSObjectProtocol] = []
    private let watchedWindows = NSHashTable<UIWindow>.weakObjects()

    /// Starts watching every window of every connected scene, and those that
    /// appear later. Safe to call repeatedly.
    func start() {
        if observers.isEmpty {
            let center = NotificationCenter.default
            for name in [UIWindow.didBecomeVisibleNotification, UIScene.didActivateNotification] {
                observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.watchWindows() }
                })
            }
        }
        watchWindows()
    }

    private func watchWindows() {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.windows.forEach(watch)
        }
    }

    /// Starts watching one window; does nothing for a window already watched.
    func watch(_ window: UIWindow) {
        guard !watchedWindows.contains(window) else { return }
        watchedWindows.add(window)
        watchTouches(in: window)
        watchFocus(of: window)
    }

    private func watchTouches(in window: UIWindow) {
        let observer = WPInteractionObserver()
        observer.onInteraction = { [weak self] window in
            guard let scene = window?.windowScene else { return }
            self?.lastInteractedScene = scene
        }
        window.addGestureRecognizer(observer)
    }

    private func watchFocus(of window: UIWindow) {
        guard #available(iOS 17.0, *) else { return }
        window.registerForTraitChanges([UITraitActiveAppearance.self]) { [weak self] (window: UIWindow, _: UITraitCollection) in
            self?.noteFocus(of: window)
        }
        // A window that already has focus will not report a change.
        noteFocus(of: window)
    }

    private func noteFocus(of window: UIWindow) {
        guard window.traitCollection.activeAppearance == .active,
              let scene = window.windowScene else { return }
        lastInteractedScene = scene
    }
}

/// Reports that a touch began in its window, then fails at once: it never
/// recognizes, never cancels or delays a touch, and neither blocks nor is
/// blocked by any other recognizer.
private final class WPInteractionObserver: UIGestureRecognizer, UIGestureRecognizerDelegate {

    var onInteraction: ((UIWindow?) -> Void)?

    init() {
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        onInteraction?(view as? UIWindow ?? view?.window)
        state = .failed
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool { true }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool { false }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool { false }
}

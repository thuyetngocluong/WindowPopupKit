import UIKit

class WPPassthroughWindow: UIWindow {

    deinit {
        WPLog.popup.debug("deinit WPPassthroughWindow")
    }

    var dismissAction: WPPopupDismissAction?
    var isKeyWindowEnabled: Bool = false
    weak var previousKeyWindow: UIWindow?

    /// When set, this window's level was forced via
    /// `WPPopupConfiguration.overrideWindowLevel`. Auto-level computation in
    /// `WPPopup.nextWindowLevel()` ignores such windows so a one-off elevated
    /// popup doesn't push subsequent auto-leveled popups beyond it.
    var overrideLevel: UIWindow.Level?

    override var canBecomeKey: Bool { isKeyWindowEnabled }

    var wpRootController: WPPopupRootViewController? {
        rootViewController as? WPPopupRootViewController
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let view = super.hitTest(point, with: event) else { return nil }
        if view === self || view === rootViewController?.view { return nil }
        return view
    }
}

// MARK: - UIKit Convenience

extension UIView {
    /// The dismiss action of the popup this view belongs to — i.e. when the
    /// view's `window` is the popup's `WPPassthroughWindow`. `nil` otherwise.
    @MainActor
    public var wpPopupDismiss: WPPopupDismissAction? {
        (window as? WPPassthroughWindow)?.dismissAction
    }
}

extension UIViewController {
    /// The dismiss action of the popup this controller belongs to — i.e. when
    /// its `view.window` is the popup's `WPPassthroughWindow`. `nil` otherwise.
    @MainActor
    public var wpPopupDismiss: WPPopupDismissAction? {
        (view.window as? WPPassthroughWindow)?.dismissAction
    }
}

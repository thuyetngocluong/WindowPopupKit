import UIKit

class WPPopupRootViewController: UIViewController {

    deinit {
        WPLog.popup.debug("deinit WPPopupRootViewController")
    }

    let backgroundView: WPPopupBackgroundView = {
        let view = WPPopupBackgroundView()
        view.alpha = 0
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(backgroundView)
        backgroundView.wpPinEdges(to: view)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        adoptCornerAdaptedSafeArea()
    }

    // MARK: - Corners and window controls

    /// What this controller has added to `additionalSafeAreaInsets` so far, so
    /// the next pass replaces its own contribution and nothing else.
    private var appliedCornerInsets: (top: CGFloat, bottom: CGFloat) = (0, 0)

    /// The plain safe area does not describe everything that can cover the top
    /// of a window: not the close / minimise / full-screen controls a windowed
    /// iPad scene draws over its content, and not the rounded corners of a
    /// display whose top inset is zero (a folded or unfolded iPhone Duo). UIKit
    /// reports both through the corner-adapted safe area — the region in which
    /// content as wide as the window is clear of them.
    ///
    /// Popups are that kind of content, so the difference is added to this
    /// view's safe area: popups anchored to the safe area start below the
    /// obstruction, and hosted SwiftUI content insets itself the same way.
    ///
    /// The obstruction is read from the window again on every layout pass, never
    /// cached: it comes and goes as the scene is resized, moved between full
    /// screen and a window, or folded — each of which lays this view out again.
    /// Only the amount this controller added is remembered, so a change replaces
    /// it instead of piling up on top.
    private func adoptCornerAdaptedSafeArea() {
        var wanted: (top: CGFloat, bottom: CGFloat) = (0, 0)
        if #available(iOS 26.0, *), let window = view.window {
            let adapted = window.edgeInsets(for: .safeArea(cornerAdaptation: .vertical))
            let plain = window.safeAreaInsets
            wanted = (max(0, adapted.top - plain.top), max(0, adapted.bottom - plain.bottom))
        }
        guard abs(wanted.top - appliedCornerInsets.top) > 0.5
            || abs(wanted.bottom - appliedCornerInsets.bottom) > 0.5 else { return }
        additionalSafeAreaInsets.top += wanted.top - appliedCornerInsets.top
        additionalSafeAreaInsets.bottom += wanted.bottom - appliedCornerInsets.bottom
        appliedCornerInsets = wanted
    }
}

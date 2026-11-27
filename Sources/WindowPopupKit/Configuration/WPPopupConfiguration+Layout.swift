import UIKit

// MARK: - Position

extension WPPopupConfiguration {

    public enum Position: Sendable {
        case top
        case center
        case bottom
        case custom(CGPoint)
    }
}

// MARK: - Position Constraints

extension WPPopupConfiguration {

    public struct PositionConstraints: Sendable {
        public var width: Edge = .fill(padding: 0)
        public var maxWidth: Edge = .intrinsic
        public var height: Edge = .intrinsic
        public var maxHeight: Edge = .intrinsic
        public var verticalOffset: CGFloat = 0
        public var safeArea: SafeArea = .init()

        /// Stretches a bottom-anchored popup upward until its top edge sits this
        /// many points below the top of the safe area.
        ///
        /// The height is then derived from the window instead of being a number,
        /// so it keeps following the window while it resizes, rotates or folds
        /// (iPhone Duo, iPad multitasking, a Mac window).
        ///
        /// Applies only when `position` is `.bottom` and `height` is `.intrinsic`;
        /// an explicit `height` wins and this value is ignored, and a `maxHeight`
        /// still caps the result. `nil` (the default) disables it.
        public var topInsetFromSafeArea: CGFloat? = nil

        public init(
            width: Edge = .fill(padding: 0),
            maxWidth: Edge = .intrinsic,
            height: Edge = .intrinsic,
            maxHeight: Edge = .intrinsic,
            verticalOffset: CGFloat = 0,
            safeArea: SafeArea = .init(),
            topInsetFromSafeArea: CGFloat? = nil
        ) {
            self.width = width
            self.maxWidth = maxWidth
            self.height = height
            self.maxHeight = maxHeight
            self.verticalOffset = verticalOffset
            self.safeArea = safeArea
            self.topInsetFromSafeArea = topInsetFromSafeArea
        }

        public var isFullScreen: Bool {
            switch (width, height) {
            case (.fill(let padding), .ratio(let ratio)):
                return padding == 0 && ratio >= 1.0
            default:
                return false
            }
        }

        public enum Edge: Sendable {
            case intrinsic
            case constant(CGFloat)
            case ratio(CGFloat)
            case fill(padding: CGFloat)
        }

        /// Whether a `.top` / `.bottom` popup is anchored to the safe area or to
        /// the edge of the window.
        ///
        /// By default (`false`) the popup's edge sits on the safe-area boundary —
        /// below the status bar or Dynamic Island, above the home indicator — and
        /// follows it while the window resizes, rotates or folds. On iOS 26 and
        /// later the boundary also clears what the plain safe area leaves out:
        /// the window controls of a windowed iPad scene, and the rounded corners
        /// of a display that has no top inset.
        ///
        /// Set a flag to `true` to anchor that edge to the window instead, so the
        /// popup's background runs under the bar. Hosted SwiftUI content still
        /// keeps itself inside the safe area; `UIView` / `UIViewController`
        /// content has to do so itself. The sheet-style presets do this at the
        /// bottom, and `defaultToast` at the top.
        ///
        /// The flags do not apply to `.center` and `.custom` positions, to a
        /// `.fill` height, or to a full-screen popup (`isFullScreen`): those are
        /// laid out against the window.
        public struct SafeArea: Sendable {
            public var overridesTop: Bool = false
            public var overridesBottom: Bool = false

            public init(overridesTop: Bool = false, overridesBottom: Bool = false) {
                self.overridesTop = overridesTop
                self.overridesBottom = overridesBottom
            }
        }
    }
}

// MARK: - Display Duration

extension WPPopupConfiguration {

    public enum DisplayDuration: Sendable {
        case infinity
        case seconds(TimeInterval)

        var nanoseconds: UInt64? {
            switch self {
            case .infinity:
                return nil
            case .seconds(let value):
                return UInt64(value * 1_000_000_000)
            }
        }
    }
}

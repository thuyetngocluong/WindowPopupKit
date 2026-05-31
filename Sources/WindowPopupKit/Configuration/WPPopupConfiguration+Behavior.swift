import UIKit

// MARK: - User Interaction

extension WPPopupConfiguration {

    public enum UserInteraction: Sendable {
        case dismiss
        case forward
        case absorbTouches
    }
}

// MARK: - Scroll (Drag to Dismiss)

extension WPPopupConfiguration {

    public struct Scroll: Sendable {
        public var isEnabled: Bool
        public var canDismiss: Bool
        public var dismissThreshold: CGFloat

        public init(isEnabled: Bool = false, canDismiss: Bool = true, dismissThreshold: CGFloat = 0.5) {
            self.isEnabled = isEnabled
            self.canDismiss = canDismiss
            self.dismissThreshold = dismissThreshold
        }

        public static let disabled = Scroll(isEnabled: false)
        public static let enabled = Scroll(isEnabled: true, dismissThreshold: 0.5)
        public static let scrollOnly = Scroll(isEnabled: true, canDismiss: false)

        /// Dismiss when user drags ≥ 1/3 of sheet height.
        public static let oneThird = Scroll(isEnabled: true, dismissThreshold: 1.0 / 3.0)
        /// Dismiss when user drags ≥ 1/4 of sheet height.
        public static let oneFourth = Scroll(isEnabled: true, dismissThreshold: 1.0 / 4.0)
        /// Dismiss when user drags ≥ 1/5 of sheet height.
        public static let oneFifth = Scroll(isEnabled: true, dismissThreshold: 1.0 / 5.0)

        public static func edgeCrossing(threshold: CGFloat = 0.5) -> Scroll {
            Scroll(isEnabled: true, dismissThreshold: threshold)
        }

        /// Custom dismiss ratio. `ratio` ∈ (0, 1) — fraction of sheet height that
        /// user must drag (in the dismiss direction) before the sheet is dismissed.
        public static func dismissAt(_ ratio: CGFloat) -> Scroll {
            Scroll(isEnabled: true, dismissThreshold: ratio)
        }
    }
}

// MARK: - Haptic Feedback

extension WPPopupConfiguration {

    public enum HapticFeedback: Sendable {
        case none
        case success
        case warning
        case error
        case light
        case medium
        case heavy
    }
}

// MARK: - Lifecycle Events

extension WPPopupConfiguration {

    public struct LifecycleEvents: @unchecked Sendable {
        public var willAppear: (() -> Void)?
        public var didAppear: (() -> Void)?
        public var willDisappear: (() -> Void)?
        public var didDisappear: (() -> Void)?

        public init(
            willAppear: (() -> Void)? = nil,
            didAppear: (() -> Void)? = nil,
            willDisappear: (() -> Void)? = nil,
            didDisappear: (() -> Void)? = nil
        ) {
            self.willAppear = willAppear
            self.didAppear = didAppear
            self.willDisappear = willDisappear
            self.didDisappear = didDisappear
        }
    }
}

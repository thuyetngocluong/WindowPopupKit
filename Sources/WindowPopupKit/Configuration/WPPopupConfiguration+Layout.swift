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

        public init(
            width: Edge = .fill(padding: 0),
            maxWidth: Edge = .intrinsic,
            height: Edge = .intrinsic,
            maxHeight: Edge = .intrinsic,
            verticalOffset: CGFloat = 0,
            safeArea: SafeArea = .init()
        ) {
            self.width = width
            self.maxWidth = maxWidth
            self.height = height
            self.maxHeight = maxHeight
            self.verticalOffset = verticalOffset
            self.safeArea = safeArea
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

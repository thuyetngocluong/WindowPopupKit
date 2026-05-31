import UIKit

// MARK: - Background Style

extension WPPopupConfiguration {

    public enum BackgroundStyle: Sendable {
        case clear
        case color(UIColor)
        case gradient(colors: [UIColor], startPoint: CGPoint, endPoint: CGPoint)
        case visualEffect(UIBlurEffect.Style)
        case image(UIImage)
    }
}

// MARK: - Shadow

extension WPPopupConfiguration {

    public struct Shadow: Sendable {
        public var color: UIColor
        public var opacity: Float
        public var radius: CGFloat
        public var offset: CGSize

        public init(
            color: UIColor = .black,
            opacity: Float = 0.2,
            radius: CGFloat = 4,
            offset: CGSize = CGSize(width: 0, height: 2)
        ) {
            self.color = color
            self.opacity = opacity
            self.radius = radius
            self.offset = offset
        }

        public static let `default` = Shadow()
    }
}

// MARK: - Round Corners

extension WPPopupConfiguration {

    public struct RoundCorners: Sendable {
        public var radius: CGFloat
        public var corners: UIRectCorner

        public init(radius: CGFloat = 0, corners: UIRectCorner = .allCorners) {
            self.radius = radius
            self.corners = corners
        }

        public static let none = RoundCorners(radius: 0)

        public static func all(_ radius: CGFloat) -> RoundCorners {
            RoundCorners(radius: radius, corners: .allCorners)
        }

        public static func top(_ radius: CGFloat) -> RoundCorners {
            RoundCorners(radius: radius, corners: [.topLeft, .topRight])
        }

        public static func bottom(_ radius: CGFloat) -> RoundCorners {
            RoundCorners(radius: radius, corners: [.bottomLeft, .bottomRight])
        }
    }
}

// MARK: - Border

extension WPPopupConfiguration {

    public struct Border: Sendable {
        public var color: UIColor
        public var width: CGFloat

        public init(color: UIColor = .separator, width: CGFloat = 1) {
            self.color = color
            self.width = width
        }
    }
}

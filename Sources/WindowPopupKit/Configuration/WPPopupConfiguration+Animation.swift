import UIKit

extension WPPopupConfiguration {

    public struct Animation: Sendable {
        public var duration: TimeInterval
        public var spring: Spring?
        public var translate: Translate?
        public var scale: Scale?
        public var fade: Fade?
        public var anchorPoint: CGPoint?

        public init(
            duration: TimeInterval = 0.3,
            spring: Spring? = nil,
            translate: Translate? = nil,
            scale: Scale? = nil,
            fade: Fade? = nil,
            anchorPoint: CGPoint? = nil
        ) {
            self.duration = duration
            self.spring = spring
            self.translate = translate
            self.scale = scale
            self.fade = fade
            self.anchorPoint = anchorPoint
        }

        // MARK: Presets

        public static let none = Animation(duration: 0)

        public static let translation = Animation(
            duration: 0.5,
            spring: .init(damping: 0.8),
            translate: .init()
        )

        public static let fade = Animation(
            duration: 0.3,
            fade: .init(from: 0)
        )

        public static let scaleAndFade = Animation(
            duration: 0.3,
            spring: .init(),
            scale: .init(from: 0.8),
            fade: .init(from: 0)
        )
    }
}

// MARK: - Animation Sub-types

extension WPPopupConfiguration.Animation {

    public struct Translate: Sendable {
        public var anchor: Anchor

        public init(anchor: Anchor = .automatic) {
            self.anchor = anchor
        }

        public enum Anchor: Sendable {
            case automatic
            case top
            case bottom
            case left
            case right
        }
    }

    public struct Scale: Sendable {
        public var from: CGFloat
        public var to: CGFloat

        public init(from: CGFloat = 0.8, to: CGFloat = 1.0) {
            self.from = from
            self.to = to
        }
    }

    public struct Fade: Sendable {
        public var from: CGFloat
        public var to: CGFloat

        public init(from: CGFloat = 0, to: CGFloat = 1.0) {
            self.from = from
            self.to = to
        }
    }

    public struct Spring: Sendable {
        public var damping: CGFloat
        public var initialVelocity: CGFloat

        public init(damping: CGFloat = 0.8, initialVelocity: CGFloat = 0.5) {
            self.damping = damping
            self.initialVelocity = initialVelocity
        }
    }
}

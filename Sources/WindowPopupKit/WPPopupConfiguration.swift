import UIKit

public struct WPPopupConfiguration: @unchecked Sendable {

    // MARK: - Layout

    public var position: Position = .center
    public var positionConstraints: PositionConstraints = .init()
    public var displayDuration: DisplayDuration = .seconds(2)
    
    // MARK: - Interaction

    public var screenInteraction: UserInteraction = .dismiss
    public var contentInteraction: UserInteraction = .absorbTouches
    public var scroll: Scroll = .disabled

    // MARK: - Appearance

    public var screenBackground: BackgroundStyle = .clear
    public var contentBackground: BackgroundStyle = .clear
    public var shadow: Shadow? = nil
    public var roundCorners: RoundCorners = .none
    public var border: Border? = nil
    public var windowInterfaceStyle: UIUserInterfaceStyle = .unspecified
    public var overrideWindowLevel: UIWindow.Level? = nil

    // MARK: - Animation

    public var entranceAnimation: Animation = .translation
    public var exitAnimation: Animation = .translation

    // MARK: - Window

    /// Makes the popup's window the **key window** while it is presented.
    ///
    /// Enable this when the popup must own keyboard input or be the first
    /// responder target — e.g. it contains a `TextField`. The previously key
    /// window is captured on present and restored automatically on dismiss.
    ///
    /// - Important: Requires full-screen `positionConstraints`
    ///   (`width: .fill(padding: 0)`, `height: .ratio(1.0)`); start from
    ///   `WPPopupConfiguration.defaultFullScreen`. A partial popup cannot
    ///   coherently *be* the key window: `WPPassthroughWindow` lets touches
    ///   outside its content fall through to the window beneath, so a
    ///   non-full-screen key window would own keyboard/focus while most of the
    ///   screen routes its touches elsewhere. Full-screen presentation also
    ///   keeps the keyboard in the content's safe-area regions so the layout can
    ///   adapt around the keyboard. `WPPopup` asserts in debug builds if this is
    ///   `true` without full-screen constraints.
    ///
    /// Defaults to `false`: the window is shown without becoming key
    /// (`canBecomeKey` stays `false`) so the app underneath keeps keyboard focus.
    public var becomeKeyWindow: Bool = false

    // MARK: - Feedback & Lifecycle

    public var hapticFeedback: HapticFeedback = .none
    public var lifecycleEvents: LifecycleEvents = .init()

    public init() {}
}

// MARK: - Presets

extension WPPopupConfiguration {

    nonisolated(unsafe) public static var defaultToast: WPPopupConfiguration = {
        var c = WPPopupConfiguration()
        c.position = .top
        c.displayDuration = .seconds(2)
        c.screenInteraction = .forward
        c.contentInteraction = .dismiss
        c.scroll = .init(isEnabled: true, dismissThreshold: 0.5)
        c.screenBackground = .clear
        c.entranceAnimation = .translation
        c.exitAnimation = .init(duration: 0.5, translate: .init())
        return c
    }()

    nonisolated(unsafe) public static var defaultPopup: WPPopupConfiguration = {
        var c = WPPopupConfiguration()
        c.position = .center
        c.displayDuration = .infinity
        c.screenInteraction = .dismiss
        c.contentInteraction = .absorbTouches
        c.scroll = .disabled
        c.screenBackground = .color(.black.withAlphaComponent(0.5))
        c.entranceAnimation = .scaleAndFade
        c.exitAnimation = .init(duration: 0.25, scale: .init(from: 1.0, to: 0.8), fade: .init(from: 1.0, to: 0))
        return c
    }()

    nonisolated(unsafe) public static var defaultLoading: WPPopupConfiguration = {
        var c = WPPopupConfiguration()
        c.position = .center
        c.displayDuration = .infinity
        c.screenInteraction = .absorbTouches
        c.contentInteraction = .absorbTouches
        c.screenBackground = .color(.black.withAlphaComponent(0.3))
        c.entranceAnimation = .scaleAndFade
        c.exitAnimation = .init(duration: 0.2, scale: .init(from: 1.0, to: 0.8), fade: .init(from: 1.0, to: 0))
        return c
    }()

    public static func defaultPopup(at point: CGPoint) -> WPPopupConfiguration {
        var c = defaultPopup
        c.position = .custom(point)
        c.positionConstraints = .init(width: .intrinsic)
        return c
    }

    nonisolated(unsafe) public static var defaultSheet: WPPopupConfiguration = {
        var c = WPPopupConfiguration()
        c.position = .bottom
        c.displayDuration = .infinity
        c.screenInteraction = .absorbTouches
        c.contentInteraction = .absorbTouches
        c.scroll = .enabled
        c.screenBackground = .color(.black.withAlphaComponent(0.3))
        c.roundCorners = .top(16)
        c.entranceAnimation = .init(duration: 0.5, spring: .init(damping: 0.85), translate: .init())
        c.exitAnimation = .init(duration: 0.25, translate: .init())
        return c
    }()

    nonisolated(unsafe) public static var defaultModal: WPPopupConfiguration = {
        var c = WPPopupConfiguration()
        let safeTopHeight: CGFloat = WPScreenMetrics.safeTopInset == 0 ? 0 : 59
        c.position = .bottom
        c.positionConstraints = .init(width: .fill(padding: 0), height: .constant(WPScreenMetrics.screenHeight - 2*safeTopHeight))
        c.displayDuration = .infinity
        c.screenInteraction = .absorbTouches
        c.contentInteraction = .absorbTouches
        c.scroll = .enabled
        c.contentBackground = .color(.systemBackground)
        c.screenBackground = .color(.black.withAlphaComponent(0.3))
        c.roundCorners = .top(16)
        c.entranceAnimation = .init(duration: 0.5, spring: .init(damping: 0.85), translate: .init())
        c.exitAnimation = .init(duration: 0.25, translate: .init())
        return c
    }()

    nonisolated(unsafe) public static var defaultFullScreen: WPPopupConfiguration = {
        var c = WPPopupConfiguration()
        c.position = .bottom
        c.positionConstraints = .init(width: .fill(padding: 0), height: .ratio(1.0))
        c.displayDuration = .infinity
        c.screenInteraction = .absorbTouches
        c.contentInteraction = .absorbTouches
        c.scroll = .disabled
        c.screenBackground = .clear
        c.entranceAnimation = .init(duration: 0.4, spring: .init(), translate: .init())
        c.exitAnimation = .init(duration: 0.3, translate: .init())
        return c
    }()
}


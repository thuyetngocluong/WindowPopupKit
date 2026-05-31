import SwiftUI
import UIKit

// MARK: - WPPopup

public final class WPPopup: @unchecked Sendable {

    public static let shared = WPPopup()

    private var activeWindows: [WPPassthroughWindow] = []

    // MARK: - Public API (SwiftUI presets)

    @discardableResult @MainActor
    public func show<Content: View>(
        configuration: WPPopupConfiguration = .init(),
        @ViewBuilder content: () -> Content
    ) async -> (any Sendable)? {
        await presentSwiftUI(content(), configuration: configuration)
    }

    @discardableResult @MainActor
    public func toast<Content: View>(
        configuration: WPPopupConfiguration = .defaultToast,
        @ViewBuilder content: () -> Content
    ) async -> (any Sendable)? {
        await presentSwiftUI(content(), configuration: configuration)
    }

    @discardableResult @MainActor
    public func popup<Content: View>(
        configuration: WPPopupConfiguration = .defaultPopup,
        @ViewBuilder content: () -> Content
    ) async -> (any Sendable)? {
        await presentSwiftUI(content(), configuration: configuration)
    }

    @discardableResult @MainActor
    public func sheet<Content: View>(
        configuration: WPPopupConfiguration = .defaultSheet,
        @ViewBuilder content: () -> Content
    ) async -> (any Sendable)? {
        await presentSwiftUI(content(), configuration: configuration)
    }

    @discardableResult @MainActor
    public func fullScreen<Content: View>(
        configuration: WPPopupConfiguration = .defaultFullScreen,
        @ViewBuilder content: () -> Content
    ) async -> (any Sendable)? {
        await presentSwiftUI(content(), configuration: configuration)
    }

    // MARK: - Show (SwiftUI)

    @discardableResult @MainActor
    public func showPopup<R, V: View>(
        swiftUIView: V,
        configuration: WPPopupConfiguration = .init()
    ) async -> R? {
        await presentSwiftUI(swiftUIView, configuration: configuration) as? R
    }

    @discardableResult @MainActor
    public func showPopup<V: View>(
        swiftUIView: V,
        configuration: WPPopupConfiguration = .init()
    ) -> WPPopupDismissAction {
        presentSwiftUIDetached(swiftUIView, configuration: configuration)
    }

    // MARK: - Show (UIViewController)

    @discardableResult @MainActor
    public func showPopup<R>(
        viewController: UIViewController,
        configuration: WPPopupConfiguration = .init()
    ) async -> R? {
        await presentContent(WPPopupContent(controller: viewController), configuration: configuration) as? R
    }

    @discardableResult @MainActor
    public func showPopup(
        viewController: UIViewController,
        configuration: WPPopupConfiguration = .init()
    ) -> WPPopupDismissAction {
        presentContentDetached(WPPopupContent(controller: viewController), configuration: configuration)
    }

    // MARK: - Show (UIView)

    @discardableResult @MainActor
    public func showPopup<R>(
        view: UIView,
        configuration: WPPopupConfiguration = .init()
    ) async -> R? {
        await presentContent(WPPopupContent(view: view), configuration: configuration) as? R
    }

    @discardableResult @MainActor
    public func showPopup(
        view: UIView,
        configuration: WPPopupConfiguration = .init()
    ) -> WPPopupDismissAction {
        presentContentDetached(WPPopupContent(view: view), configuration: configuration)
    }

    // MARK: - Presentation helpers

    @MainActor
    private func presentSwiftUI<Content: View>(
        _ content: Content,
        configuration: WPPopupConfiguration
    ) async -> (any Sendable)? {
        let dismissAction = WPPopupDismissAction()
        let popupContent = makeSwiftUIContent(content, configuration: configuration, dismissAction: dismissAction)
        return await awaitDismiss(popupContent, configuration: configuration, dismissAction: dismissAction)
    }

    @MainActor
    private func presentSwiftUIDetached<Content: View>(
        _ content: Content,
        configuration: WPPopupConfiguration
    ) -> WPPopupDismissAction {
        let dismissAction = WPPopupDismissAction()
        let popupContent = makeSwiftUIContent(content, configuration: configuration, dismissAction: dismissAction)
        _ = present(popupContent, configuration: configuration, dismissAction: dismissAction)
        return dismissAction
    }

    @MainActor
    private func presentContent(
        _ popupContent: WPPopupContent,
        configuration: WPPopupConfiguration
    ) async -> (any Sendable)? {
        let dismissAction = WPPopupDismissAction()
        return await awaitDismiss(popupContent, configuration: configuration, dismissAction: dismissAction)
    }

    @MainActor
    private func presentContentDetached(
        _ popupContent: WPPopupContent,
        configuration: WPPopupConfiguration
    ) -> WPPopupDismissAction {
        let dismissAction = WPPopupDismissAction()
        _ = present(popupContent, configuration: configuration, dismissAction: dismissAction)
        return dismissAction
    }

    @MainActor
    private func makeSwiftUIContent<Content: View>(
        _ content: Content,
        configuration: WPPopupConfiguration,
        dismissAction: WPPopupDismissAction
    ) -> WPPopupContent {
        WPPopupContent(
            swiftUI: content.environment(\.wpPopupDismiss, dismissAction),
            canBecomeKeyWindow: configuration.becomeKeyWindow
        )
    }

    @MainActor
    private func awaitDismiss(
        _ popupContent: WPPopupContent,
        configuration: WPPopupConfiguration,
        dismissAction: WPPopupDismissAction
    ) async -> (any Sendable)? {
        guard let gate = present(popupContent, configuration: configuration, dismissAction: dismissAction) else { return nil }
        await gate.value()
        return dismissAction.getReturnValue()
    }

    // MARK: - Private

    @MainActor
    private func present(
        _ content: WPPopupContent,
        configuration: WPPopupConfiguration,
        dismissAction: WPPopupDismissAction
    ) -> WPAsyncGuarantee<Void>? {
        if configuration.becomeKeyWindow && !configuration.positionConstraints.isFullScreen {
            assertionFailure(
                "[WPPopup] becomeKeyWindow requires fullScreen positionConstraints (width: .fill(padding: 0), height: .ratio(1.0)). Use .defaultFullScreen preset or set positionConstraints accordingly."
            )
        }

        guard let window = createWindow(with: configuration) else { return nil }
        
        let contentView = WPPopupContentView(content: content, configuration: configuration)

        window.dismissAction = dismissAction
        dismissAction.setPerformDismiss { [weak contentView] in
            Task { @MainActor in
                contentView?.dismissImmediately()
            }
        }

        window.isKeyWindowEnabled = configuration.becomeKeyWindow
        if configuration.becomeKeyWindow {
            window.previousKeyWindow = window.windowScene?.windows.first(where: \.isKeyWindow)
        }

        window.wpRootController?.view.addSubview(contentView)
        if configuration.becomeKeyWindow {
            window.makeKeyAndVisible()
        } else {
            window.isHidden = false
        }
        
        let dismissGate = contentView.dismissGate

        Task {
            await contentView.dismissGate.value()
            
            if configuration.becomeKeyWindow {
                restoreKeyWindow(from: window)
            }
            window.isHidden = true
            window.rootViewController = nil
            activeWindows.removeAll { $0 === window }
        }
        
        return dismissGate
    }

    @MainActor
    private func createWindow(with configuration: WPPopupConfiguration) -> WPPassthroughWindow? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first
        else { return nil }

        let window = WPPassthroughWindow(windowScene: scene)
        window.overrideUserInterfaceStyle = configuration.windowInterfaceStyle
        window.rootViewController = WPPopupRootViewController()
        if let override = configuration.overrideWindowLevel {
            window.windowLevel = override
            window.overrideLevel = override
        } else {
            window.windowLevel = nextWindowLevel()
        }
        activeWindows.append(window)
        return window
    }

    @MainActor
    private func nextWindowLevel() -> UIWindow.Level {
        let maxLevel = activeWindows
            .filter { $0.overrideLevel == nil }
            .map(\.windowLevel.rawValue)
            .max() ?? UIWindow.Level.normal.rawValue
        return UIWindow.Level(maxLevel + 1)
    }

    @MainActor
    private func restoreKeyWindow(from window: WPPassthroughWindow) {
        // Prefer the window that was key before we took over — but only if it can
        // still become key (it may have been hidden or closed in the meantime).
        if let previous = window.previousKeyWindow, !previous.isHidden, previous.canBecomeKey {
            previous.makeKey()
            return
        }

        // Otherwise fall back to the top-most visible window that can become key.
        // `canBecomeKey` already encodes WPPassthroughWindow's own rule
        // (it returns `isKeyWindowEnabled`), so a non-key-enabled passthrough
        // window is excluded while normal app windows remain eligible.
        let fallback = window.windowScene?.windows
            .filter { $0 !== window && !$0.isHidden && $0.canBecomeKey }
            .sorted { $0.windowLevel.rawValue > $1.windowLevel.rawValue }
            .first

        fallback?.makeKey()
    }
}

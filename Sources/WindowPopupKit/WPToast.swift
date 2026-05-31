import SwiftUI
import os

// MARK: - WPToastIdentifier

public struct WPToastIdentifier: Hashable, Sendable, ExpressibleByStringLiteral {

    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public static let success = WPToastIdentifier("success")
    public static let error = WPToastIdentifier("error")
    public static let warning = WPToastIdentifier("warning")
    public static let info = WPToastIdentifier("info")
    public static let network = WPToastIdentifier("network")
}

// MARK: - WPToast

public final class WPToast: Sendable {

    private typealias ShowAction = @Sendable @MainActor (String, WPPopupConfiguration) -> WPPopupDismissAction

    private struct LockedState: Sendable {
        var factories: [WPToastIdentifier: ShowAction] = [:]
        var activeActions: [WPPopupDismissAction] = []
    }

    private static let state: OSAllocatedUnfairLock<LockedState> = {
        let lock = OSAllocatedUnfairLock(initialState: LockedState())
        lock.withLock { state in
            for style in WPDefaultToastView.Style.allCases {
                let identifier = style.identifier
                state.factories[identifier] = { message, config in
                    WPPopup.shared.showPopup(
                        swiftUIView: WPDefaultToastView(style: style, message: message),
                        configuration: config
                    )
                }
            }
        }
        return lock
    }()

    private init() {}

    // MARK: - Register

    public static func register<V: View>(
        for identifier: WPToastIdentifier,
        _ factory: @escaping @Sendable @MainActor (String) -> V
    ) {
        state.withLock { state in
            state.factories[identifier] = { message, config in
                WPPopup.shared.showPopup(swiftUIView: factory(message), configuration: config)
            }
        }
    }

    // MARK: - Show

    public static func show(
        _ identifier: WPToastIdentifier,
        message: String,
        configuration: WPPopupConfiguration = .defaultToast
    ) {
        let factory = state.withLock { $0.factories[identifier] }

        guard let factory else {
            assertionFailure("[WPToast] No factory registered for identifier: \(identifier.rawValue)")
            return
        }

        Task { @MainActor in
            let dismiss = factory(message, configuration)
            trackAction(dismiss)
        }
    }

    public static func showExclusive(
        _ identifier: WPToastIdentifier,
        message: String,
        configuration: WPPopupConfiguration = .defaultToast
    ) {
        let (factory, previous) = state.withLock { state in
            let f = state.factories[identifier]
            let prev = state.activeActions
            state.activeActions.removeAll()
            return (f, prev)
        }

        guard let factory else {
            assertionFailure("[WPToast] No factory registered for identifier: \(identifier.rawValue)")
            return
        }

        Task { @MainActor in
            for action in previous { action() }
            let dismiss = factory(message, configuration)
            trackAction(dismiss)
        }
    }

    // MARK: - Dismiss

    public static func dismissAll() {
        let all = state.withLock { state in
            let actions = state.activeActions
            state.activeActions.removeAll()
            return actions
        }

        guard !all.isEmpty else { return }
        Task { @MainActor in
            for action in all { action() }
        }
    }

    private static func trackAction(_ action: WPPopupDismissAction) {
        state.withLock { $0.activeActions.append(action) }
    }
}

// MARK: - Default Toast View

private struct WPDefaultToastView: View {

    enum Style: CaseIterable, Sendable {
        case success, error, warning, info, network

        var identifier: WPToastIdentifier {
            switch self {
            case .success: .success
            case .error:   .error
            case .warning: .warning
            case .info:    .info
            case .network: .network
            }
        }

        var icon: String {
            switch self {
            case .success: "checkmark.circle.fill"
            case .error:   "xmark.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .info:    "info.circle.fill"
            case .network: "wifi.exclamationmark"
            }
        }

        var color: Color {
            switch self {
            case .success: .green
            case .error:   .red
            case .warning: .orange
            case .info:    .blue
            case .network: .gray
            }
        }
    }

    let style: Style
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: style.icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style.color.gradient)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }
}

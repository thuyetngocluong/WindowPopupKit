import SwiftUI

// MARK: - WPLoadingIdentifier

public struct WPLoadingIdentifier: Hashable, Sendable, ExpressibleByStringLiteral {

    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }
}

// MARK: - WPLoading

@MainActor
public final class WPLoading {

    private typealias ShowAction = (WPPopupConfiguration) -> WPPopupDismissAction

    private static var factories: [WPLoadingIdentifier?: ShowAction] = [
        nil: { config in
            WPPopup.shared.showPopup(swiftUIView: WPDefaultLoadingView(), configuration: config)
        }
    ]
    private static var currentDismissAction: WPPopupDismissAction?

    private init() {}

    public static func register<V: View>(
        for identifier: WPLoadingIdentifier? = nil,
        _ factory: @escaping () -> V
    ) {
        factories[identifier] = { config in
            WPPopup.shared.showPopup(swiftUIView: factory(), configuration: config)
        }
    }

    public static func showLoading(
        identifier: WPLoadingIdentifier? = nil,
        configuration: WPPopupConfiguration = .defaultLoading
    ) {
        guard let showAction = factories[identifier] ?? factories[nil] else {
            assertionFailure("[WPLoading] No factory registered for identifier: \(String(describing: identifier)). Call WPLoading.register(for:_:) first.")
            return
        }

        currentDismissAction?()
        currentDismissAction = showAction(configuration)
    }

    public static func dismissLoading() {
        guard let dismiss = currentDismissAction else { return }
        currentDismissAction = nil
        dismiss()
    }
}

// MARK: - Default Loading View

private struct WPDefaultLoadingView: View {

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 3)
                    .frame(width: 40, height: 40)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: isAnimating)
            }

            Text("Loading...")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
        }
        .padding(28)
        .background(.ultraThinMaterial.opacity(0.9))
        .background(Color.black.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear { isAnimating = true }
    }
}

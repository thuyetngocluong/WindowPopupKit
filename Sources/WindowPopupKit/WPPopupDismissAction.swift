import SwiftUI
import os

// MARK: - Dismiss Action


public final class WPPopupDismissAction: Sendable {
    private let returnValue: OSAllocatedUnfairLock<(any Sendable)?> = .init(initialState: nil)
    private let performDismiss: OSAllocatedUnfairLock<(@Sendable () -> Void)?> = .init(initialState: nil)
    
    func setPerformDismiss(_ performDismiss: @escaping @Sendable () -> Void) {
        self.performDismiss.withLock({ $0 = performDismiss })
    }
    
    func getReturnValue() -> (any Sendable)? {
        return returnValue.withLock({ $0 })
    }

    public var canDismiss: Bool {
        performDismiss.withLock({ $0 }) != nil
    }

    public func setReturnValue(_ value: (any Sendable)?) {
        returnValue.withLock({ $0 = value })
    }

    public func callAsFunction(_ returnValue: (any Sendable)? = nil) {
        if let returnValue {
            self.returnValue.withLock({ $0 = returnValue })
        }
        let performDismiss = self.performDismiss.withLock({ $0 })
        performDismiss?()
    }
}

// MARK: - Environment

private struct WPPopupDismissKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue = WPPopupDismissAction()
}

extension EnvironmentValues {
    public var wpPopupDismiss: WPPopupDismissAction {
        get { self[WPPopupDismissKey.self] }
        set { self[WPPopupDismissKey.self] = newValue }
    }
}

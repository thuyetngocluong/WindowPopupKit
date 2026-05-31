import UIKit

/// Screen / safe-area metrics used by the layout presets.
enum WPScreenMetrics {

    /// The current key window (falls back to the first window of any active scene).
    static var keyWindow: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first(where: \.isKeyWindow)
            ?? scenes.flatMap(\.windows).first
    }

    /// Full screen height. Falls back to `UIScreen.main` when no window exists yet.
    static var screenHeight: CGFloat {
        keyWindow?.bounds.height ?? UIScreen.main.bounds.height
    }

    /// Top safe-area inset (0 when unavailable).
    static var safeTopInset: CGFloat {
        keyWindow?.safeAreaInsets.top ?? 0
    }
}

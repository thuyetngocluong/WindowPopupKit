import os

/// Lightweight namespaced logger for WindowPopupKit's internal diagnostics.
enum WPLog {
    static let popup = Logger(subsystem: "com.windowpopupkit", category: "WindowPopupKit")
}

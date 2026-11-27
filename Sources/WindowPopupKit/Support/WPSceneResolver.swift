import UIKit

/// Picks the scene a popup is presented in when the caller did not name one.
///
/// An app can have several scenes connected at once (iPad multitasking, Stage
/// Manager, a Mac), and `connectedScenes` is an unordered set, so "the first
/// scene" is not a meaningful choice: it can be a background window, or simply
/// not the one the user is looking at.
enum WPSceneResolver {

    /// What the ranking needs to know about one scene.
    struct Traits: Equatable {
        var activationState: UIScene.ActivationState
        var ownsKeyWindow: Bool
        /// Whether the scene's interface is drawn as active: the window that has
        /// focus, as opposed to others of the app visible beside it.
        var hasActiveAppearance = false
        /// Whether this is the scene the user was last in: the one that last had
        /// focus or received a touch.
        var isLastInteracted = false
    }

    /// Index of the best candidate: a foreground scene before a background one,
    /// then the one drawn as active, then the one the user was last in, then
    /// one that owns a key window. `nil` only when there are no candidates.
    ///
    /// "Key window" settles nothing: each scene has one of its own, so a
    /// background iPad scene and every window of a Mac app report it at once.
    /// The active appearance is what follows focus — among the windows of an
    /// app that are on screen together, only the focused one has it, on iPad
    /// and on a Mac alike. When no window has it (a Mac app that is not
    /// frontmost), the scene the user was last in decides: the one that last
    /// had focus or was last touched. Scenes that still tie are picked between
    /// arbitrarily, and a caller that must hit a particular window names it
    /// through `WPPopupConfiguration.windowScene`.
    static func preferredIndex(among candidates: [Traits]) -> Int? {
        candidates.indices.min { lhs, rhs in
            rank(candidates[lhs]) < rank(candidates[rhs])
        }
    }

    @MainActor
    static func preferredScene(
        among scenes: [UIWindowScene],
        lastInteracted: UIWindowScene? = nil
    ) -> UIWindowScene? {
        let traits = scenes.map {
            Traits(
                activationState: $0.activationState,
                ownsKeyWindow: $0.windows.contains(where: \.isKeyWindow),
                hasActiveAppearance: $0.traitCollection.activeAppearance == .active,
                isLastInteracted: $0 === lastInteracted
            )
        }
        return preferredIndex(among: traits).map { scenes[$0] }
    }

    private static func rank(_ traits: Traits) -> Int {
        let activation: Int
        switch traits.activationState {
        case .foregroundActive: activation = 0
        case .foregroundInactive: activation = 1
        case .background: activation = 2
        case .unattached: activation = 3
        @unknown default: activation = 3
        }
        return activation * 8
            + (traits.hasActiveAppearance ? 0 : 4)
            + (traits.isLastInteracted ? 0 : 2)
            + (traits.ownsKeyWindow ? 0 : 1)
    }
}

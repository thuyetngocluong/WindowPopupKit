import XCTest
@testable import WindowPopupKit

/// What the tracker adds to a window it watches.
///
/// The record itself — which scene the user was last in — is not covered here:
/// it is a `UIWindowScene`, and the host these tests run in has none, so a
/// window made here belongs to no scene and nothing can be recorded for it.
@MainActor
final class WPActiveSceneTrackerTests: XCTestCase {

    private func makeWindow() -> UIWindow {
        UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
    }

    /// The recognizers `watch` added, told apart from the ones UIKit gives
    /// every window.
    private func watch(_ window: UIWindow, with tracker: WPActiveSceneTracker) -> [UIGestureRecognizer] {
        let before = window.gestureRecognizers ?? []
        tracker.watch(window)
        return (window.gestureRecognizers ?? []).filter { added in !before.contains { $0 === added } }
    }

    func testWatchingAWindowAgainAddsNothing() {
        let window = makeWindow()
        let tracker = WPActiveSceneTracker()

        XCTAssertEqual(watch(window, with: tracker).count, 1)
        XCTAssertEqual(watch(window, with: tracker).count, 0)
    }

    func testTheTouchObserverLeavesTouchesAlone() throws {
        let window = makeWindow()

        let observer = try XCTUnwrap(watch(window, with: WPActiveSceneTracker()).first)

        XCTAssertFalse(observer.cancelsTouchesInView)
        XCTAssertFalse(observer.delaysTouchesBegan)
        XCTAssertFalse(observer.delaysTouchesEnded)

        let tap = UITapGestureRecognizer()
        XCTAssertFalse(observer.canPrevent(tap))
        XCTAssertFalse(observer.canBePrevented(by: tap))
        XCTAssertEqual(observer.delegate?.gestureRecognizer?(observer, shouldRecognizeSimultaneouslyWith: tap), true)
    }
}

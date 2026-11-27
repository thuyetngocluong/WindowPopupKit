import XCTest
@testable import WindowPopupKit

/// Lays a popup out in a real window and checks where it lands, for window
/// shapes the presets used to get wrong: one-sided horizontal insets (a vertical
/// system bar), no top inset, and a window that is not the size of the screen.
@MainActor
final class WPPopupLayoutTests: XCTestCase {

    private var windows: [UIWindow] = []

    override func tearDown() async throws {
        await MainActor.run { windows.removeAll() }
        try await super.tearDown()
    }

    private struct Layout {
        /// The popup's frame in its window, ignoring any entrance transform.
        var frame: CGRect
        /// The safe area the window actually reported. The simulator adds its own
        /// status bar and home indicator to whatever a test asks for, so every
        /// expectation is derived from this rather than from fixed numbers.
        var safeArea: UIEdgeInsets
        var window: CGSize

        var safeCenterX: CGFloat { safeArea.left + (window.width - safeArea.left - safeArea.right) / 2 }
    }

    private struct Presented {
        var window: UIWindow
        var root: WPPopupRootViewController
        var popup: WPPopupContentView
    }

    private func layOut(
        _ configuration: WPPopupConfiguration,
        in size: CGSize = CGSize(width: 466, height: 678),
        extraSafeArea: UIEdgeInsets = .zero,
        contentSize: CGSize? = nil
    ) -> Layout {
        var configuration = configuration
        configuration.displayDuration = .infinity
        let presented = present(configuration, in: size, extraSafeArea: extraSafeArea, contentSize: contentSize)
        let popup = presented.popup

        XCTAssertEqual(presented.root.view.bounds.size, size, "the test window was not laid out at the requested size")
        return Layout(
            frame: CGRect(
                x: popup.center.x - popup.bounds.width / 2,
                y: popup.center.y - popup.bounds.height / 2,
                width: popup.bounds.width,
                height: popup.bounds.height
            ),
            safeArea: presented.root.view.safeAreaInsets,
            window: size
        )
    }

    private func present(
        _ configuration: WPPopupConfiguration,
        in size: CGSize = CGSize(width: 466, height: 678),
        extraSafeArea: UIEdgeInsets = .zero,
        contentSize: CGSize? = nil
    ) -> Presented {
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        let root = WPPopupRootViewController()
        root.additionalSafeAreaInsets = extraSafeArea
        window.rootViewController = root
        window.isHidden = false
        windows.append(window)

        let content = UIView()
        if let contentSize {
            content.translatesAutoresizingMaskIntoConstraints = false
            let width = content.widthAnchor.constraint(equalToConstant: contentSize.width)
            let height = content.heightAnchor.constraint(equalToConstant: contentSize.height)
            width.priority = .defaultHigh
            height.priority = .defaultHigh
            NSLayoutConstraint.activate([width, height])
        }

        let popup = WPPopupContentView(content: WPPopupContent(view: content), configuration: configuration)
        root.view.addSubview(popup)
        window.layoutIfNeeded()
        return Presented(window: window, root: root, popup: popup)
    }

    private func centered(width: WPPopupConfiguration.PositionConstraints.Edge) -> WPPopupConfiguration {
        var configuration = WPPopupConfiguration()
        configuration.position = .center
        configuration.positionConstraints = .init(width: width, height: .constant(100))
        return configuration
    }

    /// A system bar along one side only, as on a folded or unfolded iPhone Duo.
    private let verticalBar = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 84)

    // MARK: - Horizontal centering

    func testNarrowPopupIsCenteredInTheSafeArea() {
        let layout = layOut(centered(width: .constant(200)), extraSafeArea: verticalBar)
        XCTAssertEqual(layout.safeArea.right - layout.safeArea.left, 84, accuracy: 0.5)
        XCTAssertEqual(layout.frame.midX, layout.safeCenterX, accuracy: 0.5)
        XCTAssertEqual(layout.frame.midX, 233 - 42, accuracy: 0.5)
        XCTAssertEqual(layout.frame.width, 200, accuracy: 0.5)
    }

    func testNarrowPopupIsCenteredInTheWindowWhenInsetsAreSymmetric() {
        let symmetric = UIEdgeInsets(top: 0, left: 59, bottom: 0, right: 59)
        let layout = layOut(centered(width: .constant(200)), extraSafeArea: symmetric)
        XCTAssertEqual(layout.safeArea.left, layout.safeArea.right, accuracy: 0.5)
        XCTAssertEqual(layout.frame.midX, 233, accuracy: 0.5)
    }

    func testWidePopupStaysInsideTheWindowBesideAVerticalBar() {
        // 90% of the window does not fit beside the bar; it must not hang past
        // the opposite edge of the window to stay centered on the safe area.
        let layout = layOut(centered(width: .ratio(0.9)), extraSafeArea: verticalBar)
        XCTAssertEqual(layout.frame.width, 466 * 0.9, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(layout.frame.minX, -0.5)
        XCTAssertLessThanOrEqual(layout.frame.maxX, 466.5)
    }

    func testPopupWiderThanTheWindowStillOverflowsEvenly() {
        let layout = layOut(centered(width: .constant(600)))
        XCTAssertEqual(layout.frame.width, 600, accuracy: 0.5)
        XCTAssertEqual(layout.frame.midX, 233, accuracy: 0.5)
    }

    func testIntrinsicWidthPopupIsCenteredInTheSafeArea() {
        var configuration = centered(width: .intrinsic)
        configuration.positionConstraints.height = .intrinsic
        let layout = layOut(configuration, extraSafeArea: verticalBar, contentSize: CGSize(width: 180, height: 90))
        XCTAssertEqual(layout.frame.width, 180, accuracy: 0.5)
        XCTAssertEqual(layout.frame.midX, layout.safeCenterX, accuracy: 0.5)
    }

    func testFillWidthSpansTheWholeWindow() {
        let layout = layOut(.defaultSheet, extraSafeArea: verticalBar, contentSize: CGSize(width: 100, height: 120))
        XCTAssertEqual(layout.frame.minX, 0, accuracy: 0.5)
        XCTAssertEqual(layout.frame.width, 466, accuracy: 0.5)
        XCTAssertEqual(layout.frame.maxY, 678, accuracy: 0.5)
    }

    // MARK: - Modal

    func testDefaultModalStopsBelowTheSafeAreaAndReachesTheBottom() {
        let layout = layOut(.defaultModal, extraSafeArea: UIEdgeInsets(top: 40, left: 0, bottom: 0, right: 0))
        XCTAssertGreaterThanOrEqual(layout.safeArea.top, 40)
        XCTAssertEqual(layout.frame.minY, layout.safeArea.top + 59, accuracy: 0.5)
        XCTAssertEqual(layout.frame.maxY, 678, accuracy: 0.5)
    }

    func testDefaultModalFollowsTheWindowSize() {
        for size in [CGSize(width: 466, height: 678), CGSize(width: 951, height: 669), CGSize(width: 320, height: 480)] {
            let layout = layOut(.defaultModal, in: size, extraSafeArea: verticalBar)
            XCTAssertEqual(layout.frame.minX, 0, accuracy: 0.5)
            XCTAssertEqual(layout.frame.width, size.width, accuracy: 0.5)
            XCTAssertEqual(layout.frame.minY, layout.safeArea.top + 59, accuracy: 0.5)
            XCTAssertEqual(layout.frame.maxY, size.height, accuracy: 0.5)
        }
    }

    func testMaxHeightCapsTheModalWithoutDetachingItFromTheBottom() {
        var configuration = WPPopupConfiguration.defaultModal
        configuration.positionConstraints.maxHeight = .constant(300)
        let layout = layOut(configuration)
        XCTAssertEqual(layout.frame.height, 300, accuracy: 0.5)
        XCTAssertEqual(layout.frame.maxY, 678, accuracy: 0.5)
    }

    func testExplicitHeightWinsOverTheTopPin() {
        var configuration = WPPopupConfiguration.defaultModal
        configuration.positionConstraints.height = .ratio(0.5)
        let layout = layOut(configuration)
        XCTAssertEqual(layout.frame.height, 339, accuracy: 0.5)
        XCTAssertEqual(layout.frame.maxY, 678, accuracy: 0.5)
    }

    // MARK: - Safe-area flags

    private let barsTopAndBottom = UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0)
    private let windowRect = CGRect(x: 0, y: 0, width: 466, height: 678)

    private func anchored(
        _ position: WPPopupConfiguration.Position,
        height: WPPopupConfiguration.PositionConstraints.Edge = .intrinsic,
        verticalOffset: CGFloat = 0,
        safeArea: WPPopupConfiguration.PositionConstraints.SafeArea = .init()
    ) -> WPPopupConfiguration {
        var configuration = WPPopupConfiguration()
        configuration.position = position
        configuration.positionConstraints = .init(height: height, verticalOffset: verticalOffset, safeArea: safeArea)
        return configuration
    }

    private func assertFrame(_ frame: CGRect, equals expected: CGRect, line: UInt = #line) {
        XCTAssertEqual(frame.minX, expected.minX, accuracy: 0.5, line: line)
        XCTAssertEqual(frame.minY, expected.minY, accuracy: 0.5, line: line)
        XCTAssertEqual(frame.width, expected.width, accuracy: 0.5, line: line)
        XCTAssertEqual(frame.height, expected.height, accuracy: 0.5, line: line)
    }

    func testBottomPopupSitsOnTheSafeAreaByDefault() {
        let layout = layOut(anchored(.bottom), extraSafeArea: barsTopAndBottom, contentSize: CGSize(width: 100, height: 80))
        XCTAssertGreaterThanOrEqual(layout.safeArea.bottom, 20)
        XCTAssertEqual(layout.frame.maxY, 678 - layout.safeArea.bottom, accuracy: 0.5)
        XCTAssertEqual(layout.frame.height, 80, accuracy: 0.5)
    }

    func testOverridesBottomAnchorsToTheWindowEdge() {
        let configuration = anchored(.bottom, safeArea: .init(overridesBottom: true))
        let layout = layOut(configuration, extraSafeArea: barsTopAndBottom, contentSize: CGSize(width: 100, height: 80))
        XCTAssertEqual(layout.frame.maxY, 678, accuracy: 0.5)
    }

    func testTopPopupSitsBelowTheSafeAreaByDefault() {
        let layout = layOut(anchored(.top, verticalOffset: 6), extraSafeArea: barsTopAndBottom, contentSize: CGSize(width: 100, height: 80))
        XCTAssertGreaterThanOrEqual(layout.safeArea.top, 20)
        XCTAssertEqual(layout.frame.minY, layout.safeArea.top + 6, accuracy: 0.5)
    }

    func testOverridesTopAnchorsToTheWindowEdge() {
        let configuration = anchored(.top, verticalOffset: 6, safeArea: .init(overridesTop: true))
        let layout = layOut(configuration, extraSafeArea: barsTopAndBottom, contentSize: CGSize(width: 100, height: 80))
        XCTAssertEqual(layout.frame.minY, 6, accuracy: 0.5)
    }

    func testVerticalOffsetLiftsABottomPopupOffTheSafeArea() {
        let layout = layOut(anchored(.bottom, verticalOffset: 12), extraSafeArea: barsTopAndBottom, contentSize: CGSize(width: 100, height: 80))
        XCTAssertEqual(layout.frame.maxY, 678 - layout.safeArea.bottom - 12, accuracy: 0.5)
    }

    func testFlagsDoNotMoveACenteredPopup() {
        let layout = layOut(anchored(.center), extraSafeArea: UIEdgeInsets(top: 60, left: 0, bottom: 0, right: 0), contentSize: CGSize(width: 100, height: 80))
        XCTAssertEqual(layout.frame.midY, 339, accuracy: 0.5)
    }

    func testFullScreenPopupCoversTheWindowWhateverTheFlags() {
        // The hand-built shape `becomeKeyWindow` asks for, anchored either way.
        for position in [WPPopupConfiguration.Position.top, .bottom, .center] {
            let layout = layOut(anchored(position, height: .ratio(1.0)), extraSafeArea: barsTopAndBottom)
            assertFrame(layout.frame, equals: windowRect)
        }
    }

    func testDefaultFullScreenCoversTheWindow() {
        let layout = layOut(.defaultFullScreen, extraSafeArea: barsTopAndBottom)
        assertFrame(layout.frame, equals: windowRect)
    }

    func testFillHeightSpansTheWindowWithoutFightingThePosition() {
        for position in [WPPopupConfiguration.Position.top, .bottom, .center] {
            let layout = layOut(anchored(position, height: .fill(padding: 0)), extraSafeArea: barsTopAndBottom)
            assertFrame(layout.frame, equals: windowRect)
        }
    }

    // MARK: - Resizing during an animation

    func testResizeDuringAnAnchoredAnimationLeavesThePopupWhereLayoutPutsIt() async throws {
        // A scale animation about the popup's top-left corner, caught mid-flight
        // by a window resize (a fold, a window drag).
        var configuration = centered(width: .constant(200))
        configuration.displayDuration = .infinity
        configuration.entranceAnimation = .init(
            duration: 0.4,
            scale: .init(from: 0.5, to: 1),
            anchorPoint: CGPoint(x: 0, y: 0)
        )
        let presented = present(configuration)

        let popup = presented.popup
        try await Task.sleep(nanoseconds: 100_000_000)
        // Without this the resize could miss the animation on a slow machine
        // and the test would pass against any implementation.
        XCTAssertFalse(popup.layer.animationKeys()?.isEmpty ?? true, "the entrance animation is not in flight")
        presented.window.frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        presented.window.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 900_000_000)

        XCTAssertEqual(popup.frame.midX, 400, accuracy: 0.5)
        XCTAssertEqual(popup.frame.midY, 300, accuracy: 0.5)
        XCTAssertEqual(popup.frame.width, 200, accuracy: 0.5)
    }

    func testAnchoredScaleKeepsItsAnchorInPlace() {
        // The transform is applied about the view's center, so points are
        // measured from there: the top-left corner of a 200 x 100 view.
        let size = CGSize(width: 200, height: 100)
        let topLeft = CGPoint(x: -100, y: -50)
        let anchored = WPPopupContentView.scaling(by: 0.5, about: CGPoint(x: 0, y: 0), in: size)
        XCTAssertEqual(topLeft.applying(anchored).x, topLeft.x, accuracy: 0.001)
        XCTAssertEqual(topLeft.applying(anchored).y, topLeft.y, accuracy: 0.001)
        // ...while the opposite corner travels half the diagonal toward it.
        let bottomRight = CGPoint(x: 100, y: 50).applying(anchored)
        XCTAssertEqual(bottomRight.x, 0, accuracy: 0.001)
        XCTAssertEqual(bottomRight.y, 0, accuracy: 0.001)

        // Without an anchor, and about the center, it is a plain scale.
        let plain = CGAffineTransform(scaleX: 0.5, y: 0.5)
        XCTAssertEqual(WPPopupContentView.scaling(by: 0.5, about: nil, in: size), plain)
        XCTAssertEqual(WPPopupContentView.scaling(by: 0.5, about: CGPoint(x: 0.5, y: 0.5), in: size), plain)
    }

    // MARK: - Toast

    func testDefaultToastKeepsAMarginFromTheTopEdge() {
        let layout = layOut(.defaultToast, extraSafeArea: verticalBar, contentSize: CGSize(width: 100, height: 44))
        XCTAssertEqual(layout.frame.minY, 8, accuracy: 0.5)
        XCTAssertEqual(layout.frame.width, 466, accuracy: 0.5)
    }
}

import XCTest
@testable import WindowPopupKit

final class WPPopupConfigurationTests: XCTestCase {

    // MARK: - DisplayDuration

    func testDisplayDurationInfinityHasNoNanoseconds() {
        XCTAssertNil(WPPopupConfiguration.DisplayDuration.infinity.nanoseconds)
    }

    func testDisplayDurationSecondsConvertsToNanoseconds() {
        XCTAssertEqual(WPPopupConfiguration.DisplayDuration.seconds(2).nanoseconds, 2_000_000_000)
        XCTAssertEqual(WPPopupConfiguration.DisplayDuration.seconds(0.5).nanoseconds, 500_000_000)
    }

    // MARK: - PositionConstraints.isFullScreen

    func testIsFullScreenTrueForFillZeroAndRatioOne() {
        let constraints = WPPopupConfiguration.PositionConstraints(width: .fill(padding: 0), height: .ratio(1.0))
        XCTAssertTrue(constraints.isFullScreen)
    }

    func testIsFullScreenFalseWhenPaddingNonZero() {
        let constraints = WPPopupConfiguration.PositionConstraints(width: .fill(padding: 8), height: .ratio(1.0))
        XCTAssertFalse(constraints.isFullScreen)
    }

    func testIsFullScreenFalseWhenRatioBelowOne() {
        let constraints = WPPopupConfiguration.PositionConstraints(width: .fill(padding: 0), height: .ratio(0.9))
        XCTAssertFalse(constraints.isFullScreen)
    }

    func testIsFullScreenFalseWhenWidthNotFill() {
        let constraints = WPPopupConfiguration.PositionConstraints(width: .constant(320), height: .ratio(1.0))
        XCTAssertFalse(constraints.isFullScreen)
    }

    func testDefaultPositionConstraintsAreNotFullScreen() {
        XCTAssertFalse(WPPopupConfiguration.PositionConstraints().isFullScreen)
    }

    // MARK: - Scroll

    func testScrollPresets() {
        XCTAssertFalse(WPPopupConfiguration.Scroll.disabled.isEnabled)

        XCTAssertTrue(WPPopupConfiguration.Scroll.enabled.isEnabled)
        XCTAssertEqual(WPPopupConfiguration.Scroll.enabled.dismissThreshold, 0.5)
        XCTAssertTrue(WPPopupConfiguration.Scroll.enabled.canDismiss)

        XCTAssertTrue(WPPopupConfiguration.Scroll.scrollOnly.isEnabled)
        XCTAssertFalse(WPPopupConfiguration.Scroll.scrollOnly.canDismiss)
    }

    func testScrollThresholdHelpers() {
        XCTAssertEqual(WPPopupConfiguration.Scroll.oneThird.dismissThreshold, 1.0 / 3.0)
        XCTAssertEqual(WPPopupConfiguration.Scroll.oneFourth.dismissThreshold, 0.25)
        XCTAssertEqual(WPPopupConfiguration.Scroll.oneFifth.dismissThreshold, 0.2)

        let custom = WPPopupConfiguration.Scroll.dismissAt(0.42)
        XCTAssertTrue(custom.isEnabled)
        XCTAssertEqual(custom.dismissThreshold, 0.42)

        XCTAssertEqual(WPPopupConfiguration.Scroll.edgeCrossing(threshold: 0.6).dismissThreshold, 0.6)
    }

    // MARK: - Presets

    func testDefaultToastPreset() {
        let config = WPPopupConfiguration.defaultToast
        XCTAssertTrue(config.position.isTop)
        XCTAssertEqual(config.displayDuration.nanoseconds, 2_000_000_000)
        XCTAssertFalse(config.becomeKeyWindow)
    }

    func testDefaultPopupPreset() {
        let config = WPPopupConfiguration.defaultPopup
        XCTAssertTrue(config.position.isCenter)
        XCTAssertNil(config.displayDuration.nanoseconds)
    }

    func testDefaultSheetIsBottomAnchored() {
        XCTAssertTrue(WPPopupConfiguration.defaultSheet.position.isBottom)
    }

    func testDefaultFullScreenIsFullScreen() {
        XCTAssertTrue(WPPopupConfiguration.defaultFullScreen.positionConstraints.isFullScreen)
    }

    func testDefaultModalIsNotFullScreen() {
        // Modal uses a constant height, so it is intentionally not a full-screen layout.
        XCTAssertFalse(WPPopupConfiguration.defaultModal.positionConstraints.isFullScreen)
    }

    func testDefaultPopupAtPointUsesCustomPosition() {
        let config = WPPopupConfiguration.defaultPopup(at: CGPoint(x: 10, y: 20))
        XCTAssertTrue(config.position.isCustom)
    }

    // MARK: - Animation

    func testAnimationNoneHasZeroDuration() {
        XCTAssertEqual(WPPopupConfiguration.Animation.none.duration, 0)
    }

    func testAnimationPresetsComposeExpectedLayers() {
        XCTAssertNotNil(WPPopupConfiguration.Animation.fade.fade)
        XCTAssertNil(WPPopupConfiguration.Animation.fade.scale)

        let scaleAndFade = WPPopupConfiguration.Animation.scaleAndFade
        XCTAssertNotNil(scaleAndFade.scale)
        XCTAssertNotNil(scaleAndFade.fade)
        XCTAssertNotNil(scaleAndFade.spring)

        let translation = WPPopupConfiguration.Animation.translation
        XCTAssertNotNil(translation.translate)
        XCTAssertNotNil(translation.spring)
    }

    func testAnimationSubtypeDefaults() {
        let scale = WPPopupConfiguration.Animation.Scale()
        XCTAssertEqual(scale.from, 0.8)
        XCTAssertEqual(scale.to, 1.0)

        let fade = WPPopupConfiguration.Animation.Fade()
        XCTAssertEqual(fade.from, 0)
        XCTAssertEqual(fade.to, 1.0)

        let spring = WPPopupConfiguration.Animation.Spring()
        XCTAssertEqual(spring.damping, 0.8)
        XCTAssertEqual(spring.initialVelocity, 0.5)
    }

    // MARK: - Identifiers

    func testToastIdentifierEqualityAndLiteral() {
        XCTAssertEqual(WPToastIdentifier.success.rawValue, "success")
        XCTAssertEqual(WPToastIdentifier("custom"), WPToastIdentifier("custom"))

        let literal: WPToastIdentifier = "from-literal"
        XCTAssertEqual(literal.rawValue, "from-literal")
    }

    func testLoadingIdentifierEqualityAndLiteral() {
        XCTAssertEqual(WPLoadingIdentifier("a"), WPLoadingIdentifier("a"))
        XCTAssertNotEqual(WPLoadingIdentifier("a"), WPLoadingIdentifier("b"))

        let literal: WPLoadingIdentifier = "spinner"
        XCTAssertEqual(literal.rawValue, "spinner")
    }
}

// MARK: - Test Helpers

private extension WPPopupConfiguration.Position {
    var isTop: Bool { if case .top = self { return true }; return false }
    var isCenter: Bool { if case .center = self { return true }; return false }
    var isBottom: Bool { if case .bottom = self { return true }; return false }
    var isCustom: Bool { if case .custom = self { return true }; return false }
}

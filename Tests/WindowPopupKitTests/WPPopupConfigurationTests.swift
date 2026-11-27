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
        // Modal stops short of the top, so it is intentionally not a full-screen layout.
        XCTAssertFalse(WPPopupConfiguration.defaultModal.positionConstraints.isFullScreen)
    }

    func testDefaultModalHeightFollowsTheWindow() {
        // No number captured from a screen or a window: the height is derived from
        // a top pin against the safe area, so it stays right when the window resizes.
        let constraints = WPPopupConfiguration.defaultModal.positionConstraints
        XCTAssertTrue(WPPopupConfiguration.defaultModal.position.isBottom)
        XCTAssertNotNil(constraints.topInsetFromSafeArea)
        guard case .intrinsic = constraints.height else {
            return XCTFail("defaultModal must not carry a fixed height")
        }
    }

    func testTopInsetFromSafeAreaIsOffByDefault() {
        XCTAssertNil(WPPopupConfiguration.PositionConstraints().topInsetFromSafeArea)
        XCTAssertNil(WPPopupConfiguration.defaultSheet.positionConstraints.topInsetFromSafeArea)
    }

    func testSafeAreaIsRespectedUnlessAPresetOptsOut() {
        let plain = WPPopupConfiguration.PositionConstraints().safeArea
        XCTAssertFalse(plain.overridesTop)
        XCTAssertFalse(plain.overridesBottom)

        // Surfaces meant to reach the window edge say so explicitly.
        XCTAssertTrue(WPPopupConfiguration.defaultSheet.positionConstraints.safeArea.overridesBottom)
        XCTAssertTrue(WPPopupConfiguration.defaultModal.positionConstraints.safeArea.overridesBottom)
        XCTAssertTrue(WPPopupConfiguration.defaultToast.positionConstraints.safeArea.overridesTop)
    }

    func testWindowSceneIsUnsetByDefault() {
        XCTAssertNil(WPPopupConfiguration().windowScene)
        XCTAssertNil(WPPopupConfiguration.defaultToast.windowScene)
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

// MARK: - Scene resolution

final class WPSceneResolverTests: XCTestCase {

    private typealias Traits = WPSceneResolver.Traits

    func testNoCandidatesYieldsNil() {
        XCTAssertNil(WPSceneResolver.preferredIndex(among: []))
    }

    func testForegroundSceneBeatsBackgroundScene() {
        let candidates = [
            Traits(activationState: .background, ownsKeyWindow: true),
            Traits(activationState: .foregroundActive, ownsKeyWindow: false)
        ]
        XCTAssertEqual(WPSceneResolver.preferredIndex(among: candidates), 1)
    }

    func testKeyWindowBreaksTieBetweenForegroundScenes() {
        // Two foreground scenes, neither focused nor touched yet: the one that
        // owns a key window is the last-resort pick.
        let candidates = [
            Traits(activationState: .foregroundActive, ownsKeyWindow: false),
            Traits(activationState: .foregroundActive, ownsKeyWindow: true)
        ]
        XCTAssertEqual(WPSceneResolver.preferredIndex(among: candidates), 1)
    }

    func testActiveAppearanceBreaksTieBetweenKeyWindows() {
        // On a Mac every window of the app can report itself key at once; the
        // frontmost one is the only one drawn as active.
        let candidates = [
            Traits(activationState: .foregroundActive, ownsKeyWindow: true),
            Traits(activationState: .foregroundActive, ownsKeyWindow: true, hasActiveAppearance: true)
        ]
        XCTAssertEqual(WPSceneResolver.preferredIndex(among: candidates), 1)
    }

    func testLastTouchSettlesScenesTheSystemCannotTellApart() {
        // Two Mac windows of one app: both foreground, both "key". Only the
        // record of where the user last clicked separates them.
        let candidates = [
            Traits(activationState: .foregroundActive, ownsKeyWindow: true),
            Traits(activationState: .foregroundActive, ownsKeyWindow: true, isLastInteracted: true)
        ]
        XCTAssertEqual(WPSceneResolver.preferredIndex(among: candidates), 1)
    }

    func testLastTouchDoesNotResurrectABackgroundScene() {
        // The window touched last may since have been sent to the background.
        let candidates = [
            Traits(activationState: .background, ownsKeyWindow: false, isLastInteracted: true),
            Traits(activationState: .foregroundActive, ownsKeyWindow: false)
        ]
        XCTAssertEqual(WPSceneResolver.preferredIndex(among: candidates), 1)
    }

    func testLastTouchOutranksKeyWindow() {
        // Every scene has a key window of its own, so "key" says little; where
        // the user last touched says which window they are in.
        let candidates = [
            Traits(activationState: .foregroundActive, ownsKeyWindow: true),
            Traits(activationState: .foregroundActive, ownsKeyWindow: false, isLastInteracted: true)
        ]
        XCTAssertEqual(WPSceneResolver.preferredIndex(among: candidates), 1)
    }

    func testActiveAppearanceOutranksAnOlderTouch() {
        // The user clicked in one Mac window, then brought another to the front
        // without touching its content.
        let candidates = [
            Traits(activationState: .foregroundActive, ownsKeyWindow: true, isLastInteracted: true),
            Traits(activationState: .foregroundActive, ownsKeyWindow: true, hasActiveAppearance: true)
        ]
        XCTAssertEqual(WPSceneResolver.preferredIndex(among: candidates), 1)
    }

    func testBackgroundSceneWithAKeyWindowLosesToTheVisibleOne() {
        // Measured on iPad: a scene sent to the background still reports a key
        // window. It must not capture the popup.
        let candidates = [
            Traits(activationState: .background, ownsKeyWindow: true),
            Traits(activationState: .foregroundActive, ownsKeyWindow: true, hasActiveAppearance: true, isLastInteracted: true)
        ]
        XCTAssertEqual(WPSceneResolver.preferredIndex(among: candidates), 1)
    }

    func testActivationStateOutranksActiveAppearance() {
        let candidates = [
            Traits(activationState: .background, ownsKeyWindow: true, hasActiveAppearance: true),
            Traits(activationState: .foregroundActive, ownsKeyWindow: false)
        ]
        XCTAssertEqual(WPSceneResolver.preferredIndex(among: candidates), 1)
    }

    func testActiveSceneBeatsInactiveScene() {
        let candidates = [
            Traits(activationState: .foregroundInactive, ownsKeyWindow: true),
            Traits(activationState: .foregroundActive, ownsKeyWindow: false)
        ]
        XCTAssertEqual(WPSceneResolver.preferredIndex(among: candidates), 1)
    }

    func testFallsBackToWhateverIsConnected() {
        // While the app is still launching nothing is in the foreground yet; a
        // popup shown then must still find a scene.
        let candidates = [
            Traits(activationState: .unattached, ownsKeyWindow: false),
            Traits(activationState: .background, ownsKeyWindow: false)
        ]
        XCTAssertEqual(WPSceneResolver.preferredIndex(among: candidates), 1)
    }
}

// MARK: - Test Helpers

private extension WPPopupConfiguration.Position {
    var isTop: Bool { if case .top = self { return true }; return false }
    var isCenter: Bool { if case .center = self { return true }; return false }
    var isBottom: Bool { if case .bottom = self { return true }; return false }
    var isCustom: Bool { if case .custom = self { return true }; return false }
}

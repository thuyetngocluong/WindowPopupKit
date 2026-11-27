import XCTest
@testable import WindowPopupKit

/// Drag-to-dismiss on a sheet whose content has a fixed header above a scroll
/// view, driven through the popup's own pan handler with a scripted recognizer.
@MainActor
final class WPPopupDragTests: XCTestCase {

    private var windows: [UIWindow] = []

    override func tearDown() async throws {
        await MainActor.run { windows.removeAll() }
        try await super.tearDown()
    }

    /// A pan recognizer that reports what the test tells it to, the way the
    /// real one would: its location is where the finger is now, and its
    /// translation counts from the touch-down or from the last reset.
    private final class ScriptedPan: UIPanGestureRecognizer {
        var scriptedState: UIGestureRecognizer.State = .possible
        /// Where the finger went down, in the popup's coordinate space.
        private(set) var touchDown: CGPoint = .zero
        /// How far down the finger has moved since.
        var travelled: CGFloat = 0
        private var translationOrigin: CGFloat = 0
        weak var popup: UIView?

        func putFingerDown(at point: CGPoint) {
            touchDown = point
            travelled = 0
            translationOrigin = 0
        }

        override var state: UIGestureRecognizer.State {
            get { scriptedState }
            set { scriptedState = newValue }
        }

        override func translation(in view: UIView?) -> CGPoint {
            CGPoint(x: 0, y: travelled - translationOrigin)
        }

        override func setTranslation(_ translation: CGPoint, in view: UIView?) {
            translationOrigin = travelled - translation.y
        }

        override func location(in view: UIView?) -> CGPoint {
            let now = CGPoint(x: touchDown.x, y: touchDown.y + travelled)
            guard let popup, let view else { return now }
            return popup.convert(now, to: view)
        }
    }

    /// How far a finger moves before UIKit recognizes a pan.
    private static let recognitionDistance: CGFloat = 10

    private struct Sheet {
        var popup: WPPopupContentView
        var list: UIScrollView
        var pan: ScriptedPan

        static let headerHeight: CGFloat = 60
        /// A point on the fixed header, and one on the list below it.
        static let onHeader = CGPoint(x: 100, y: 20)
        static let onList = CGPoint(x: 100, y: 200)
    }

    /// A 400 pt bottom sheet: a 60 pt header above a scroll view with far more
    /// content than fits.
    private func presentSheet(
        scrolledTo offset: CGFloat,
        scroll: WPPopupConfiguration.Scroll = .enabled,
        onDismiss: @escaping () -> Void = {}
    ) -> Sheet {
        var configuration = WPPopupConfiguration.defaultSheet
        configuration.positionConstraints.height = .constant(400)
        configuration.scroll = scroll
        configuration.lifecycleEvents.willDisappear = onDismiss

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        let root = WPPopupRootViewController()
        window.rootViewController = root
        window.isHidden = false
        windows.append(window)

        let content = UIView()
        let header = UIView()
        let list = UIScrollView()
        for view in [header, list] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: content.topAnchor),
            header.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: Sheet.headerHeight),
            list.topAnchor.constraint(equalTo: header.bottomAnchor),
            list.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            list.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            list.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])

        let popup = WPPopupContentView(content: WPPopupContent(view: content), configuration: configuration)
        root.view.addSubview(popup)
        window.layoutIfNeeded()

        list.contentSize = CGSize(width: 400, height: 3000)
        list.contentOffset.y = offset

        let pan = ScriptedPan()
        pan.popup = popup
        return Sheet(popup: popup, list: list, pan: pan)
    }

    /// Delivers one recognizer callback with the finger `travelled` points
    /// below where it went down.
    private func send(_ sheet: Sheet, _ state: UIGestureRecognizer.State, travelled: CGFloat) {
        sheet.pan.scriptedState = state
        sheet.pan.travelled = travelled
        sheet.popup.perform(NSSelectorFromString("handlePan:"), with: sheet.pan)
    }

    /// Puts a finger down at `start`; the pan is recognized a few points later.
    private func beginDrag(_ sheet: Sheet, at start: CGPoint) {
        sheet.pan.putFingerDown(at: start)
        send(sheet, .began, travelled: Self.recognitionDistance)
    }

    /// Puts a finger down at `start` and moves it `distance` points down.
    private func drag(_ sheet: Sheet, from start: CGPoint, by distance: CGFloat) {
        beginDrag(sheet, at: start)
        send(sheet, .changed, travelled: distance)
    }

    // MARK: - Where the drag starts

    func testHeaderDragMovesTheSheetWhileTheListIsScrolled() {
        let sheet = presentSheet(scrolledTo: 150)
        XCTAssertGreaterThan(sheet.list.bounds.height, 300, "the sheet was not laid out")

        drag(sheet, from: Sheet.onHeader, by: 120)

        XCTAssertEqual(sheet.popup.transform.ty, 120, accuracy: 0.5, "a drag on the header must move the sheet wherever the list is")
        XCTAssertEqual(sheet.list.contentOffset.y, 150, accuracy: 0.5, "the list must stay where the user left it")
    }

    func testListDragScrollsTheListBeforeItMovesTheSheet() {
        let sheet = presentSheet(scrolledTo: 150)

        drag(sheet, from: Sheet.onList, by: 120)

        XCTAssertEqual(sheet.popup.transform.ty, 0, accuracy: 0.5, "the list has not reached its top yet")
    }

    func testListDragMovesTheSheetOnceTheListIsAtItsTop() {
        let sheet = presentSheet(scrolledTo: 0)

        beginDrag(sheet, at: Sheet.onList)
        // The list's own pan follows the same finger and pulls its content past
        // the top; the sheet takes the drag over and puts the list back.
        sheet.list.contentOffset.y = -30
        send(sheet, .changed, travelled: 120)

        XCTAssertEqual(sheet.popup.transform.ty, 120, accuracy: 0.5)
        XCTAssertEqual(sheet.list.contentOffset.y, 0, accuracy: 0.5, "the list must not move while the sheet is being dragged")

        sheet.list.contentOffset.y = -18
        send(sheet, .changed, travelled: 160)

        XCTAssertEqual(sheet.list.contentOffset.y, 0, accuracy: 0.5, "the list must stay put for the rest of the drag")
    }

    func testDragThatStartsOnTheHeaderAndIsRecognizedOverTheListIsAHeaderDrag() {
        // The finger lands on the last few points of the header; by the time the
        // pan is recognized it has crossed onto the list.
        let sheet = presentSheet(scrolledTo: 150)
        let bottomOfHeader = CGPoint(x: 100, y: Sheet.headerHeight - 4)
        XCTAssertGreaterThan(bottomOfHeader.y + Self.recognitionDistance, Sheet.headerHeight)

        drag(sheet, from: bottomOfHeader, by: 120)

        XCTAssertEqual(sheet.popup.transform.ty, 120, accuracy: 0.5)
        XCTAssertEqual(sheet.list.contentOffset.y, 150, accuracy: 0.5)
    }

    func testDragThatStartsOnTheListAndIsRecognizedOverTheHeaderIsAListDrag() {
        // The mirror image: down on the first points of the list, moving up.
        let sheet = presentSheet(scrolledTo: 150)
        sheet.pan.putFingerDown(at: CGPoint(x: 100, y: Sheet.headerHeight + 4))
        send(sheet, .began, travelled: -Self.recognitionDistance)
        send(sheet, .changed, travelled: 120)

        XCTAssertEqual(sheet.popup.transform.ty, 0, accuracy: 0.5, "the list has not reached its top yet")
    }

    // MARK: - Letting go

    func testHeaderDragPastTheThresholdDismissesAScrolledSheet() {
        var dismissed = false
        let sheet = presentSheet(scrolledTo: 150) { dismissed = true }

        drag(sheet, from: Sheet.onHeader, by: 120)
        send(sheet, .changed, travelled: 400)   // 280 since the sheet took the drag: past half of 400
        send(sheet, .ended, travelled: 400)

        XCTAssertTrue(dismissed)
    }

    func testHeaderDragShortOfTheThresholdLeavesTheSheetUp() {
        var dismissed = false
        let sheet = presentSheet(scrolledTo: 150) { dismissed = true }

        drag(sheet, from: Sheet.onHeader, by: 120)
        send(sheet, .changed, travelled: 250)   // 130 since the sheet took the drag: short of half
        XCTAssertEqual(sheet.popup.transform.ty, 130, accuracy: 0.5)
        send(sheet, .ended, travelled: 250)

        XCTAssertFalse(dismissed)
    }

    func testScrollOnlyNeverDismissesFromTheHeader() {
        var dismissed = false
        let sheet = presentSheet(scrolledTo: 150, scroll: .scrollOnly) { dismissed = true }

        drag(sheet, from: Sheet.onHeader, by: 120)
        send(sheet, .changed, travelled: 500)
        send(sheet, .ended, travelled: 500)

        XCTAssertFalse(dismissed)
    }
}

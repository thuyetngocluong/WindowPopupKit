import SwiftUI
import UIKit

@MainActor
struct WPPopupContent {

    class HostingController<Content: View>: UIHostingController<Content> {

        let canBecomeKeyWindow: Bool

        init(rootView: Content, canBecomeKeyWindow: Bool) {
            self.canBecomeKeyWindow = canBecomeKeyWindow
            super.init(rootView: rootView)
        }

        @MainActor @preconcurrency required dynamic init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            if !canBecomeKeyWindow, #available(iOS 16.4, *) {
                safeAreaRegions.remove(.keyboard)
            }
        }
    }

    let controller: UIViewController?
    let view: UIView

    init(view: UIView) {
        self.view = view
        self.controller = nil
    }

    init(controller: UIViewController) {
        self.controller = controller
        self.view = controller.view
    }

    init<Content: View>(swiftUI: Content, canBecomeKeyWindow: Bool) {
        let hosting = HostingController(rootView: swiftUI, canBecomeKeyWindow: canBecomeKeyWindow)
        hosting.view.backgroundColor = .clear
        self.init(controller: hosting)
    }
}

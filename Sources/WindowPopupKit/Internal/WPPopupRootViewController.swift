import UIKit

class WPPopupRootViewController: UIViewController {

    deinit {
        WPLog.popup.debug("deinit WPPopupRootViewController")
    }

    let backgroundView: WPPopupBackgroundView = {
        let view = WPPopupBackgroundView()
        view.alpha = 0
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(backgroundView)
        backgroundView.wpPinEdges(to: view)
    }
}

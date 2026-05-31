import UIKit

class WPPopupBackgroundView: UIView {
    
    deinit {
        WPLog.popup.debug("deinit WPPopupBackgroundView")
    }

    var interaction: WPPopupConfiguration.UserInteraction = .dismiss
    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        switch interaction {
        case .forward:
            return nil
        case .dismiss, .absorbTouches:
            return super.hitTest(point, with: event)
        }
    }

    @objc private func handleTap() {
        guard interaction == .dismiss else { return }
        onTap?()
    }
}

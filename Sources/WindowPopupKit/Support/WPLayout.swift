import UIKit

extension UIView {

    /// Pins this view's edges to `other`, activating the constraints immediately.
    ///
    /// Replaces the SnapKit `edges.equalToSuperview()` calls so WindowPopupKit
    /// stays dependency-free.
    func wpPinEdges(to other: UIView, insets: UIEdgeInsets = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: other.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: other.trailingAnchor, constant: -insets.right),
            topAnchor.constraint(equalTo: other.topAnchor, constant: insets.top),
            bottomAnchor.constraint(equalTo: other.bottomAnchor, constant: -insets.bottom)
        ])
    }
}

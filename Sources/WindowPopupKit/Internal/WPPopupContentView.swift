import UIKit

private class GradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }
    var gradientLayer: CAGradientLayer { layer as! CAGradientLayer }
}

class WPPopupContentView: UIView {
    
    deinit {
        WPLog.popup.debug("deinit WPPopupContentView")
    }

    let content: WPPopupContent
    let configuration: WPPopupConfiguration

    weak var backgroundView: WPPopupBackgroundView?
    let dismissGate = WPAsyncGuarantee<Void>()

    private var isDismissed: Bool = false
    private var autoDismissTask: Task<Void, any Error>?
    private weak var trackedScrollView: UIScrollView?
    private var isDraggingSheet: Bool = false
    private var panStartedInsideScroll: Bool = false
    private lazy var panGesture: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        gesture.delegate = self
        return gesture
    }()

    init(content: WPPopupContent, configuration: WPPopupConfiguration) {
        self.content = content
        self.configuration = configuration
        super.init(frame: .zero)
        self.alpha = 0
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if configuration.contentInteraction == .forward {
            return nil
        }
        return super.hitTest(point, with: event)
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if let parentController = self.superview?.next as? WPPopupRootViewController {
            setup(parentController: parentController)
        }
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil && !isDismissed {
            dismiss()
        }
    }

    // MARK: - Public

    func dismissImmediately() {
        dismiss()
    }

    // MARK: - Setup

    private func setup(parentController: WPPopupRootViewController) {
        backgroundView = parentController.backgroundView
        backgroundView?.interaction = configuration.screenInteraction

        addSubview(content.view)
        content.view.wpPinEdges(to: self)
        if let contentController = content.controller {
            parentController.addChild(contentController)
            contentController.didMove(toParent: parentController)
        }

        if configuration.contentInteraction == .dismiss {
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleContentTap))
            addGestureRecognizer(tap)
        }

        setupConstraints()
        applyContentAppearance()
        configureBackgroundView()
        layoutIfNeeded()

        if configuration.scroll.isEnabled {
            addGestureRecognizer(panGesture)
            trackedScrollView = findScrollView(in: content.view)
        }

        triggerHaptic()
        configuration.lifecycleEvents.willAppear?()

        Task {
            await animateIn()
            configuration.lifecycleEvents.didAppear?()
            startAutoDismissIfNeeded()
        }
    }

    // MARK: - Layout

    private func setupConstraints() {
        let constraints = configuration.positionConstraints
        
        guard let superview else { return }
        translatesAutoresizingMaskIntoConstraints = false

        let isCustomPosition: Bool = {
            if case .custom = configuration.position { return true }
            return false
        }()

        var active: [NSLayoutConstraint] = []

        // Width
        switch constraints.width {
        case .intrinsic:
            if !isCustomPosition { active.append(centerXAnchor.constraint(equalTo: superview.centerXAnchor)) }
        case .constant(let value):
            active.append(widthAnchor.constraint(equalToConstant: value))
            if !isCustomPosition { active.append(centerXAnchor.constraint(equalTo: superview.centerXAnchor)) }
        case .ratio(let ratio):
            active.append(widthAnchor.constraint(equalTo: superview.widthAnchor, multiplier: ratio))
            if !isCustomPosition { active.append(centerXAnchor.constraint(equalTo: superview.centerXAnchor)) }
        case .fill(let padding):
            if !isCustomPosition {
                active.append(leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: padding))
                active.append(trailingAnchor.constraint(equalTo: superview.trailingAnchor, constant: -padding))
            } else {
                active.append(widthAnchor.constraint(equalTo: superview.widthAnchor, constant: -2 * padding))
            }
        }

        // Max width
        switch constraints.maxWidth {
        case .intrinsic:
            break
        case .constant(let value):
            active.append(widthAnchor.constraint(lessThanOrEqualToConstant: value))
        case .ratio(let ratio):
            active.append(widthAnchor.constraint(lessThanOrEqualTo: superview.widthAnchor, multiplier: ratio))
        case .fill(let padding):
            active.append(widthAnchor.constraint(lessThanOrEqualTo: superview.widthAnchor, constant: -2 * padding))
        }

        // Height
        switch constraints.height {
        case .intrinsic:
            break
        case .constant(let value):
            active.append(heightAnchor.constraint(equalToConstant: value))
        case .ratio(let ratio):
            active.append(heightAnchor.constraint(equalTo: superview.heightAnchor, multiplier: ratio))
        case .fill(let padding):
            if !isCustomPosition {
                active.append(topAnchor.constraint(equalTo: superview.topAnchor, constant: padding))
                active.append(bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: -padding))
            } else {
                active.append(heightAnchor.constraint(equalTo: superview.heightAnchor, constant: -2 * padding))
            }
        }

        // Max height
        switch constraints.maxHeight {
        case .intrinsic:
            break
        case .constant(let value):
            active.append(heightAnchor.constraint(lessThanOrEqualToConstant: value))
        case .ratio(let ratio):
            active.append(heightAnchor.constraint(lessThanOrEqualTo: superview.heightAnchor, multiplier: ratio))
        case .fill(let padding):
            active.append(heightAnchor.constraint(lessThanOrEqualTo: superview.heightAnchor, constant: -2 * padding))
        }

        // Position
        let offset = constraints.verticalOffset
        switch configuration.position {
        case .top:
            let topInset = constraints.safeArea.overridesTop ? 0 : safeAreaInsets.top
            active.append(topAnchor.constraint(equalTo: superview.topAnchor, constant: topInset + offset))
        case .center:
            active.append(centerYAnchor.constraint(equalTo: superview.centerYAnchor, constant: offset))
        case .bottom:
            let bottomInset = constraints.safeArea.overridesBottom ? 0 : safeAreaInsets.bottom
            active.append(bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: -(bottomInset + offset)))
        case .custom(let point):
            active.append(centerXAnchor.constraint(equalTo: superview.leadingAnchor, constant: point.x))
            active.append(centerYAnchor.constraint(equalTo: superview.topAnchor, constant: point.y))
        }

        NSLayoutConstraint.activate(active)
    }

    // MARK: - Appearance

    private func applyContentAppearance() {
        // Background
        switch configuration.contentBackground {
        case .clear:
            backgroundColor = .clear
        case .color(let color):
            backgroundColor = color
        case .visualEffect(let style):
            let blurView = UIVisualEffectView(effect: UIBlurEffect(style: style))
            insertSubview(blurView, at: 0)
            blurView.wpPinEdges(to: self)
        case .gradient(let colors, let start, let end):
            let gradientView = GradientView()
            gradientView.gradientLayer.colors = colors.map(\.cgColor)
            gradientView.gradientLayer.startPoint = start
            gradientView.gradientLayer.endPoint = end
            insertSubview(gradientView, at: 0)
            gradientView.wpPinEdges(to: self)
        case .image(let image):
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            insertSubview(imageView, at: 0)
            imageView.wpPinEdges(to: self)
        }

        // Round Corners
        let rc = configuration.roundCorners
        if rc.radius > 0 {
            layer.cornerRadius = rc.radius
            clipsToBounds = true
            if rc.corners != .allCorners {
                var maskedCorners: CACornerMask = []
                if rc.corners.contains(.topLeft) { maskedCorners.insert(.layerMinXMinYCorner) }
                if rc.corners.contains(.topRight) { maskedCorners.insert(.layerMaxXMinYCorner) }
                if rc.corners.contains(.bottomLeft) { maskedCorners.insert(.layerMinXMaxYCorner) }
                if rc.corners.contains(.bottomRight) { maskedCorners.insert(.layerMaxXMaxYCorner) }
                layer.maskedCorners = maskedCorners
            }
        }

        // Shadow
        if let shadow = configuration.shadow {
            layer.shadowColor = shadow.color.cgColor
            layer.shadowOpacity = shadow.opacity
            layer.shadowRadius = shadow.radius
            layer.shadowOffset = shadow.offset
            clipsToBounds = false
        }

        // Border
        if let border = configuration.border {
            layer.borderColor = border.color.cgColor
            layer.borderWidth = border.width
        }
    }

    private func configureBackgroundView() {
        backgroundView?.interaction = configuration.screenInteraction
        backgroundView?.onTap = { [weak self] in
            self?.dismiss()
        }

        guard let backgroundView else { return }

        switch configuration.screenBackground {
        case .clear:
            backgroundView.backgroundColor = .clear
        case .color(let color):
            backgroundView.backgroundColor = color
        case .visualEffect(let style):
            let blurView = UIVisualEffectView(effect: UIBlurEffect(style: style))
            backgroundView.addSubview(blurView)
            blurView.wpPinEdges(to: backgroundView)
        case .gradient(let colors, let start, let end):
            let gradientView = GradientView()
            gradientView.gradientLayer.colors = colors.map(\.cgColor)
            gradientView.gradientLayer.startPoint = start
            gradientView.gradientLayer.endPoint = end
            backgroundView.addSubview(gradientView)
            gradientView.wpPinEdges(to: backgroundView)
        case .image(let image):
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            backgroundView.addSubview(imageView)
            imageView.wpPinEdges(to: backgroundView)
        }
    }

    private func startAutoDismissIfNeeded() {
        guard let ns = configuration.displayDuration.nanoseconds else { return }
        autoDismissTask = Task {
            try await Task.sleep(nanoseconds: ns)
            self.dismiss()
        }
    }

    // MARK: - Haptic

    private func triggerHaptic() {
        switch configuration.hapticFeedback {
        case .none: break
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }

    // MARK: - Gesture

    @objc private func handleContentTap() {
        dismiss()
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard !isDismissed else { return }
        let translation = gesture.translation(in: superview)

        switch gesture.state {
        case .began:
            if trackedScrollView == nil {
                trackedScrollView = findScrollView(in: content.view)
            }
            if let scroll = trackedScrollView {
                let loc = gesture.location(in: scroll)
                panStartedInsideScroll = scroll.bounds.contains(loc)
            } else {
                panStartedInsideScroll = false
            }
            isDraggingSheet = false
        case .changed:
            handlePanChanged(gesture: gesture, translation: translation)
        case .ended, .cancelled:
            handlePanEnded(translation: translation)
        default:
            break
        }
    }

    // MARK: - Pan Phases

    /// Phase 1: Non-dismiss direction (e.g. scroll up on bottom sheet) — sheet rubber-bands when inner scroll is at its top
    /// Phase 2: Dismiss direction (e.g. scroll down on bottom sheet) → evaluate sheet drag vs inner scroll
    private func handlePanChanged(gesture: UIPanGestureRecognizer, translation: CGPoint) {
        let isDismissDir = isDismissDirection(translation.y)

        // Phase 1: Non-dismiss direction
        if !isDismissDir {
            if isDraggingSheet && transform.ty == 0 {
                isDraggingSheet = false
                gesture.setTranslation(.zero, in: superview)
            }
            // Sheet rubber-bands when:
            //   • inner scroll is at its top edge, OR
            //   • the pan started outside the scroll view (e.g. on a header/handle).
            // Otherwise the inner scroll absorbs the gesture normally.
            let scrollAtTop = (trackedScrollView?.contentOffset.y ?? 0) <= 0
            let allowSheetOverdrag = scrollAtTop || !panStartedInsideScroll
            if !allowSheetOverdrag {
                if !isDraggingSheet { return }
            } else {
                isDraggingSheet = true
                if scrollAtTop { trackedScrollView?.contentOffset.y = 0 }
                let y = rubberBandOffset(translation.y, dimension: max(bounds.height, 1))
                transform = CGAffineTransform(translationX: 0, y: y)
                return
            }
        }

        // Phase 2: Dismiss direction → decide sheet drag vs inner scroll
        if !isDraggingSheet {
            guard shouldBeginSheetDrag(gesture: gesture) else { return }
        }

        trackedScrollView?.contentOffset.y = 0

        let y = isDismissDir ? translation.y : 0
        transform = CGAffineTransform(translationX: 0, y: y)
        updateBackgroundAlpha(for: y)
    }

    private func rubberBandOffset(_ offset: CGFloat, dimension: CGFloat, coeff: CGFloat = 0.55) -> CGFloat {
        guard dimension > 0 else { return 0 }
        let resistance = (1 - 1 / (abs(offset) * coeff / dimension + 1)) * dimension
        return offset < 0 ? -resistance : resistance
    }

    private func shouldBeginSheetDrag(gesture: UIPanGestureRecognizer) -> Bool {
        if let scrollView = trackedScrollView {
            guard scrollView.contentOffset.y <= 0 else { return false }
            scrollView.contentOffset.y = 0
        }
        isDraggingSheet = true
        gesture.setTranslation(.zero, in: superview)
        return true
    }

    private func handlePanEnded(translation: CGPoint) {
        defer { isDraggingSheet = false }
        guard isDraggingSheet else { return }

        if configuration.scroll.canDismiss && isDismissDistance(translation.y) {
            dismiss()
        } else {
            UIView.animate(
                withDuration: 0.4,
                delay: 0,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.5,
                options: [],
                animations: {
                    self.transform = .identity
                    self.backgroundView?.alpha = 1
                }
            )
        }
    }

    // MARK: - Dismiss Direction Helpers

    private func isDismissDirection(_ y: CGFloat) -> Bool {
        switch configuration.position {
        case .bottom:
            return y > 0
        case .top:
            return y < 0
        case .center, .custom:
            return y < 0
        }
    }

    private func isDismissDistance(_ y: CGFloat) -> Bool {
        let threshold = bounds.height * configuration.scroll.dismissThreshold
        switch configuration.position {
        case .bottom:
            return y > threshold
        case .top:
            return y < -threshold
        case .center, .custom:
            return abs(y) > threshold
        }
    }

    private func updateBackgroundAlpha(for y: CGFloat) {
        let dismissY = isDismissDirection(y) ? abs(y) : 0
        let progress = min(dismissY / 200, 1.0)
        backgroundView?.alpha = 1 - progress * 0.5
    }

    // MARK: - ScrollView

    private func findScrollView(in view: UIView) -> UIScrollView? {
        if let scrollView = view as? UIScrollView {
            return scrollView
        }
        for subview in view.subviews {
            if let found = findScrollView(in: subview) {
                return found
            }
        }
        return nil
    }

    // MARK: - Animation

    private func animateIn() async {
        guard let superview else { return }

        let anim = configuration.entranceAnimation
        let savedAnchor = applyAnchorPointIfNeeded(anim.anchorPoint)
        applyEntranceState(in: superview, animation: anim)
        backgroundView?.alpha = 0

        let targetAlpha = anim.fade?.to ?? 1
        let targetScale = anim.scale?.to ?? 1
        await withCheckedContinuation { continuation in
            Self.performAnimation(anim) {
                self.transform = targetScale == 1
                    ? .identity
                    : CGAffineTransform(scaleX: targetScale, y: targetScale)
                self.alpha = targetAlpha
                self.backgroundView?.alpha = 1
            } completion: { [weak self] in
                self?.restoreAnchorPointIfNeeded(savedAnchor)
                continuation.resume()
            }
        }
    }

    private func applyEntranceState(in superview: UIView, animation: WPPopupConfiguration.Animation) {
        var tx: CGFloat = 0
        var ty: CGFloat = 0

        if let translate = animation.translate {
            let frameBounds = convert(bounds, to: superview)
            switch resolveAnchor(translate.anchor) {
            case .top:
                ty = -frameBounds.maxY - superview.safeAreaInsets.top
            case .bottom:
                ty = superview.bounds.height - frameBounds.minY
            case .left:
                tx = -frameBounds.maxX
            case .right:
                tx = superview.bounds.width - frameBounds.minX
            default:
                break
            }
        }

        transform = CGAffineTransform(translationX: tx, y: ty)

        if let scale = animation.scale {
            transform = transform.scaledBy(x: scale.from, y: scale.from)
        }

        alpha = animation.fade != nil ? animation.fade!.from : 1
    }

    private func dismiss() {
        guard !isDismissed else { return }
        isDismissed = true
        autoDismissTask?.cancel()
        configuration.lifecycleEvents.willDisappear?()

        guard let superview else {
            removeContent()
            return
        }

        let anim = configuration.exitAnimation
        let savedAnchor = applyAnchorPointIfNeeded(anim.anchorPoint)
        var targetTransform = exitTranslation(in: superview)
        if let scale = anim.scale {
            targetTransform = targetTransform.scaledBy(x: scale.to, y: scale.to)
        }
        let targetAlpha: CGFloat = anim.fade?.to ?? 1

        Self.performAnimation(anim) {
            self.transform = targetTransform
            self.alpha = targetAlpha
            self.backgroundView?.alpha = 0
        } completion: { [weak self] in
            self?.restoreAnchorPointIfNeeded(savedAnchor)
            self?.removeContent()
        }
    }

    private func exitTranslation(in superview: UIView) -> CGAffineTransform {
        guard let translate = configuration.exitAnimation.translate else { return .identity }
        let saved = transform
        transform = .identity
        let frameBounds = convert(bounds, to: superview)
        transform = saved
        switch resolveAnchor(translate.anchor) {
        case .top:
            return .init(translationX: 0, y: -frameBounds.maxY)
        case .bottom:
            return .init(translationX: 0, y: superview.bounds.height - frameBounds.minY)
        case .left:
            return .init(translationX: -frameBounds.maxX, y: 0)
        case .right:
            return .init(translationX: superview.bounds.width - frameBounds.minX, y: 0)
        default:
            return .identity
        }
    }

    private static func performAnimation(
        _ animation: WPPopupConfiguration.Animation,
        animations: @escaping () -> Void,
        completion: @escaping () -> Void
    ) {
        if let spring = animation.spring {
            UIView.animate(
                withDuration: animation.duration,
                delay: 0,
                usingSpringWithDamping: spring.damping,
                initialSpringVelocity: spring.initialVelocity,
                options: [],
                animations: animations,
                completion: { _ in completion() }
            )
        } else {
            UIView.animate(
                withDuration: animation.duration,
                delay: 0,
                options: .curveEaseInOut,
                animations: animations,
                completion: { _ in completion() }
            )
        }
    }

    private func resolveAnchor(_ anchor: WPPopupConfiguration.Animation.Translate.Anchor) -> WPPopupConfiguration.Animation.Translate.Anchor {
        guard case .automatic = anchor else { return anchor }
        switch configuration.position {
        case .top: return .top
        case .bottom: return .bottom
        case .center, .custom: return .top
        }
    }

    private func applyAnchorPointIfNeeded(_ anchorPoint: CGPoint?) -> CGPoint? {
        guard let anchorPoint else { return nil }
        let saved = layer.anchorPoint
        let bounds = bounds
        let oldAnchor = layer.anchorPoint
        layer.anchorPoint = anchorPoint
        let dx = (anchorPoint.x - oldAnchor.x) * bounds.width
        let dy = (anchorPoint.y - oldAnchor.y) * bounds.height
        layer.position = CGPoint(x: layer.position.x + dx, y: layer.position.y + dy)
        return saved
    }

    private func restoreAnchorPointIfNeeded(_ saved: CGPoint?) {
        guard let saved else { return }
        let bounds = bounds
        let oldAnchor = layer.anchorPoint
        layer.anchorPoint = saved
        let dx = (saved.x - oldAnchor.x) * bounds.width
        let dy = (saved.y - oldAnchor.y) * bounds.height
        layer.position = CGPoint(x: layer.position.x + dx, y: layer.position.y + dy)
    }

    private func removeContent() {
        if let controller = content.controller {
            controller.view.removeFromSuperview()
            controller.removeFromParent()
        } else {
            content.view.removeFromSuperview()
        }
        removeFromSuperview()
        configuration.lifecycleEvents.didDisappear?()
        dismissGate.resolve(with: ())
    }
}

// MARK: - UIGestureRecognizerDelegate

extension WPPopupContentView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return otherGestureRecognizer.view is UIScrollView
    }
}

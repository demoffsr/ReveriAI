import SwiftUI
import ObjectiveC

private var swipeBackDelegateKey: UInt8 = 0

// MARK: - Custom Pop Animator

/// Pop animation mimicking native iOS parallax behavior (Settings, Messages, Mail):
/// - Back view slides from -30% to 0 (parallax)
/// - Front view slides from 0 to screenWidth
/// - Dimming overlay fades from 0.1 to 0
/// - Shadow on left edge of front view
final class SlidePopAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    private var animator: UIViewPropertyAnimator?
    private static let parallaxRatio: CGFloat = 0.3
    private static let dimmingAlpha: CGFloat = 0.1
    private static let shadowOpacity: Float = 0.06
    /// Reads the device's actual screen corner radius (matches the physical display rounding)
    private static var cornerRadius: CGFloat {
        (UIScreen.main.value(forKey: "_displayCornerRadius") as? CGFloat) ?? 44
    }

    func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
        0.35
    }

    func interruptibleAnimator(using transitionContext: any UIViewControllerContextTransitioning) -> any UIViewImplicitlyAnimating {
        if let existing = animator {
            return existing
        }

        guard let fromView = transitionContext.view(forKey: .from),
              let toView = transitionContext.view(forKey: .to) else {
            let empty = UIViewPropertyAnimator(duration: 0, curve: .linear) {}
            self.animator = empty
            return empty
        }

        let containerView = transitionContext.containerView
        let containerWidth = containerView.bounds.width
        let finalFrame = transitionContext.finalFrame(for: transitionContext.viewController(forKey: .to)!)

        // Back view starts offset to the left (parallax)
        toView.frame = finalFrame
        toView.frame.origin.x = -containerWidth * Self.parallaxRatio
        containerView.insertSubview(toView, at: 0)

        // Dimming overlay between back and front views
        let dimmingView = UIView(frame: containerView.bounds)
        dimmingView.backgroundColor = .black
        dimmingView.alpha = Self.dimmingAlpha
        containerView.insertSubview(dimmingView, aboveSubview: toView)

        // Rounded corners on the front (detail) view
        fromView.layer.cornerRadius = Self.cornerRadius
        fromView.layer.cornerCurve = .continuous
        fromView.clipsToBounds = true

        // Shadow on a separate view (clipsToBounds on fromView would clip its own shadow)
        let shadowView = UIView(frame: fromView.frame)
        shadowView.backgroundColor = .clear
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowOffset = CGSize(width: -3, height: 0)
        shadowView.layer.shadowRadius = 6
        shadowView.layer.shadowOpacity = Self.shadowOpacity
        shadowView.layer.shadowPath = UIBezierPath(roundedRect: fromView.bounds, cornerRadius: Self.cornerRadius).cgPath
        containerView.insertSubview(shadowView, belowSubview: fromView)

        let duration = transitionDuration(using: transitionContext)
        let propertyAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1.0) {
            fromView.frame.origin.x = containerWidth
            shadowView.frame.origin.x = containerWidth
            toView.frame.origin.x = 0
            dimmingView.alpha = 0
        }

        propertyAnimator.addCompletion { position in
            shadowView.removeFromSuperview()
            dimmingView.removeFromSuperview()
            fromView.layer.cornerRadius = 0
            fromView.clipsToBounds = false
            let completed = position == .end
            if !completed {
                toView.removeFromSuperview()
            }
            transitionContext.completeTransition(completed)
        }

        self.animator = propertyAnimator
        return propertyAnimator
    }

    func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
        let anim = interruptibleAnimator(using: transitionContext)
        anim.startAnimation()
    }
}

// MARK: - Swipe Back Delegate (Gesture + Navigation)

final class SwipeBackDelegate: NSObject, UIGestureRecognizerDelegate, UINavigationControllerDelegate {
    weak var navigationController: UINavigationController?
    weak var originalDelegate: UINavigationControllerDelegate?
    var interactionController: UIPercentDrivenInteractiveTransition?

    // MARK: UIGestureRecognizerDelegate

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let nav = navigationController else { return false }
        return nav.viewControllers.count > 1 && nav.transitionCoordinator == nil
    }

    // MARK: UINavigationControllerDelegate

    func navigationController(
        _ navigationController: UINavigationController,
        animationControllerFor operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> (any UIViewControllerAnimatedTransitioning)? {
        switch operation {
        case .pop:
            return SlidePopAnimator()
        default:
            return nil // Standard iOS push animation
        }
    }

    func navigationController(
        _ navigationController: UINavigationController,
        interactionControllerFor animationController: any UIViewControllerAnimatedTransitioning
    ) -> (any UIViewControllerInteractiveTransitioning)? {
        interactionController
    }

    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        originalDelegate?.navigationController?(navigationController, willShow: viewController, animated: animated)
    }

    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        originalDelegate?.navigationController?(navigationController, didShow: viewController, animated: animated)
    }

    // MARK: Proxy for unknown selectors (NavigationStack internal delegate methods)

    override func responds(to aSelector: Selector!) -> Bool {
        if super.responds(to: aSelector) { return true }
        return originalDelegate?.responds(to: aSelector) ?? false
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if let original = originalDelegate, original.responds(to: aSelector) {
            return original
        }
        return super.forwardingTarget(for: aSelector)
    }

    // MARK: Edge Pan Gesture

    func installEdgePan(on nav: UINavigationController) {
        let edgePan = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdgePan(_:)))
        edgePan.edges = .left
        edgePan.delegate = self
        nav.view.addGestureRecognizer(edgePan)
    }

    @objc private func handleEdgePan(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard let nav = navigationController else { return }
        let translation = gesture.translation(in: gesture.view)
        let width = gesture.view?.bounds.width ?? UIScreen.main.bounds.width
        let progress = max(0, min(1, translation.x / width))

        switch gesture.state {
        case .began:
            interactionController = UIPercentDrivenInteractiveTransition()
            nav.popViewController(animated: true)

        case .changed:
            interactionController?.update(progress)

        case .ended:
            let velocity = gesture.velocity(in: gesture.view).x
            if progress > 0.35 || velocity > 800 {
                let speedFactor = max(0.5, min(1.5, velocity / 1000))
                interactionController?.completionSpeed = speedFactor
                interactionController?.finish()
            } else {
                // Ensure cancel takes at least 0.25s so it doesn't snap back harshly
                let remainingDuration = 0.35 * Double(progress)
                let minDuration = 0.25
                interactionController?.completionSpeed = CGFloat(remainingDuration / max(minDuration, remainingDuration))
                interactionController?.cancel()
            }
            interactionController = nil

        case .cancelled, .failed:
            interactionController?.cancel()
            interactionController = nil

        default:
            break
        }
    }
}

// MARK: - UIViewControllerRepresentable

struct SwipeBackGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        SwipeBackController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    final class SwipeBackController: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let nav = navigationController else { return }

            let delegate: SwipeBackDelegate
            if let existing = objc_getAssociatedObject(nav, &swipeBackDelegateKey) as? SwipeBackDelegate {
                delegate = existing
                // Re-capture original delegate if NavigationStack replaced it
                if nav.delegate !== delegate {
                    delegate.originalDelegate = nav.delegate
                    nav.delegate = delegate
                }
            } else {
                delegate = SwipeBackDelegate()
                delegate.navigationController = nav
                delegate.originalDelegate = nav.delegate
                nav.delegate = delegate

                // Disable built-in pop gesture — we use our own edge pan
                nav.interactivePopGestureRecognizer?.isEnabled = false

                // Install custom edge pan recognizer
                delegate.installEdgePan(on: nav)

                objc_setAssociatedObject(nav, &swipeBackDelegateKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }

            nav.view.backgroundColor = .systemGroupedBackground
        }
    }
}

extension View {
    func enableSwipeBack() -> some View {
        background(SwipeBackGestureEnabler())
    }
}

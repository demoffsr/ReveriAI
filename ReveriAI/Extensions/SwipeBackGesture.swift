import SwiftUI
import ObjectiveC

private var swipeBackDelegateKey: UInt8 = 0

struct SwipeBackGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        SwipeBackController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    final class SwipeBackController: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let nav = navigationController,
                  let gesture = nav.interactivePopGestureRecognizer else { return }

            // Reuse or create delegate associated with the nav controller itself
            // Associated object ensures delegate outlives any pushed view controller
            let delegate: SwipeBackDelegate
            if let existing = objc_getAssociatedObject(nav, &swipeBackDelegateKey) as? SwipeBackDelegate {
                delegate = existing
            } else {
                delegate = SwipeBackDelegate()
                delegate.navigationController = nav
                objc_setAssociatedObject(nav, &swipeBackDelegateKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }

            gesture.isEnabled = true
            gesture.delegate = delegate
        }
    }

    final class SwipeBackDelegate: NSObject, UIGestureRecognizerDelegate {
        weak var navigationController: UINavigationController?

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let nav = navigationController else { return false }
            // Block on root VC (prevents freeze) and during active transition (prevents shift)
            return nav.viewControllers.count > 1 && nav.transitionCoordinator == nil
        }
    }
}

extension View {
    func enableSwipeBack() -> some View {
        background(SwipeBackGestureEnabler())
    }
}

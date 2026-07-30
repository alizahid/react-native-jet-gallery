import SDWebImage
import UIKit

final class GalleryTransitionDelegate: NSObject, UIViewControllerTransitioningDelegate {
  // The session owns this delegate, and the view controller retains the
  // session for the delegate's whole lifetime — but weak (over unowned)
  // means a future ownership change degrades to a default transition
  // instead of a crash.
  private weak var session: GallerySession?

  init(session: GallerySession) {
    self.session = session
  }

  func animationController(
    forPresented presented: UIViewController,
    presenting: UIViewController,
    source: UIViewController
  ) -> UIViewControllerAnimatedTransitioning? {
    guard let session else {
      return nil
    }

    return GalleryPresentAnimator(session: session)
  }

  func animationController(
    forDismissed dismissed: UIViewController
  ) -> UIViewControllerAnimatedTransitioning? {
    guard let session else {
      return nil
    }

    return GalleryDismissAnimator(session: session)
  }
}

private func aspectFitRect(for size: CGSize, in bounds: CGRect) -> CGRect {
  guard size.width > 0, size.height > 0 else {
    return bounds
  }

  let scale = min(bounds.width / size.width, bounds.height / size.height)
  let fitted = CGSize(width: size.width * scale, height: size.height * scale)

  return CGRect(
    x: bounds.midX - fitted.width / 2,
    y: bounds.midY - fitted.height / 2,
    width: fitted.width,
    height: fitted.height
  )
}

private func aspectFillRect(for size: CGSize, in bounds: CGRect) -> CGRect {
  guard size.width > 0, size.height > 0 else {
    return bounds
  }

  let scale = max(bounds.width / size.width, bounds.height / size.height)
  let filled = CGSize(width: size.width * scale, height: size.height * scale)

  return CGRect(
    x: bounds.midX - filled.width / 2,
    y: bounds.midY - filled.height / 2,
    width: filled.width,
    height: filled.height
  )
}

private func cachedImage(for url: String) -> UIImage? {
  guard let parsed = url.hasPrefix("/") ? URL(fileURLWithPath: url) : URL(string: url) else {
    return nil
  }

  guard
    let key = SDWebImageManager.shared.cacheKey(for: parsed, context: GalleryPageCell.decodeContext)
  else {
    return nil
  }

  // Memory-only: a disk hit here would decode synchronously on the main
  // thread right as the transition starts. A miss falls back to the
  // source-view snapshot.
  return SDImageCache.shared.imageFromMemoryCache(forKey: key)
}

/// An image view mirroring the transitioned image; keeps GIFs animating mid-flight.
private func makeTransitionImageView(image: UIImage?) -> UIImageView {
  let view = SDAnimatedImageView()

  view.image = image
  view.contentMode = .scaleAspectFill
  view.clipsToBounds = true
  view.layer.cornerCurve = .continuous

  return view
}

final class GalleryPresentAnimator: NSObject, UIViewControllerAnimatedTransitioning {
  private let session: GallerySession

  init(session: GallerySession) {
    self.session = session
  }

  func transitionDuration(
    using transitionContext: UIViewControllerContextTransitioning?
  ) -> TimeInterval {
    return 0.42
  }

  func animateTransition(using context: UIViewControllerContextTransitioning) {
    guard let controller = context.viewController(forKey: .to) as? GalleryViewController else {
      context.completeTransition(false)
      return
    }

    let container = context.containerView

    controller.view.frame = container.bounds
    container.addSubview(controller.view)
    controller.view.layoutIfNeeded()

    var startRect: CGRect?
    var startRadius: CGFloat = 0

    if let sourceView = session.sourceView, sourceView.window != nil {
      startRect = sourceView.convert(sourceView.bounds, to: container)
      startRadius = sourceView.layer.cornerRadius
    } else if let origin = session.origin {
      startRect = origin.rect
      startRadius = origin.borderRadius
    }

    let image = cachedImage(for: session.url(at: session.initialIndex))

    var animatedView: UIView?
    // A snapshot stretches when its bounds change aspect, unlike an image
    // view's aspect-fill. Snapshots go inside a clipping wrapper and this
    // keeps a reference so the animation can grow it to fill the target.
    var fillContent: UIView?

    if let start = startRect {
      if image != nil {
        animatedView = makeTransitionImageView(image: image)
      } else {
        var snapshot = session.sourceView?.snapshotView(afterScreenUpdates: false)

        if snapshot == nil, start.width > 0, start.height > 0,
           let fromView = context.viewController(forKey: .from)?.view {
          // Imperative opens pass an origin rect but usually no sourceTag, and
          // on first open the image is not in the memory cache yet — snapshot
          // the pixels already on screen so the zoom transition still runs
          // instead of degrading to a fade.
          snapshot = fromView.resizableSnapshotView(
            from: fromView.convert(start, from: container),
            afterScreenUpdates: false,
            withCapInsets: .zero
          )
        }

        if let snapshot {
          let wrapper = UIView()
          wrapper.clipsToBounds = true
          wrapper.layer.cornerCurve = .continuous

          snapshot.frame = CGRect(origin: .zero, size: start.size)
          wrapper.addSubview(snapshot)

          animatedView = wrapper
          fillContent = snapshot
        }
      }
    }

    guard let start = startRect, let animated = animatedView else {
      controller.view.alpha = 0
      controller.view.transform = CGAffineTransform(scaleX: 1.06, y: 1.06)

      UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut]) {
        controller.view.alpha = 1
        controller.view.transform = .identity
      } completion: { _ in
        context.completeTransition(!context.transitionWasCancelled)
      }

      return
    }

    session.hideSourceView()

    // The declared size keeps the transition landing on the image's real
    // aspect even when the full image hasn't loaded yet (snapshot path).
    let target = aspectFitRect(
      for: image?.size ?? session.imageSize(at: session.initialIndex) ?? start.size,
      in: container.bounds
    )

    animated.frame = start
    animated.layer.cornerRadius = startRadius
    container.addSubview(animated)

    controller.view.alpha = 0
    controller.pager.alpha = 0

    UIView.animate(
      withDuration: transitionDuration(using: context),
      delay: 0,
      usingSpringWithDamping: 0.88,
      initialSpringVelocity: 0.4
    ) {
      animated.frame = target
      animated.layer.cornerRadius = 0
      // The snapshot keeps its own aspect and grows to cover the wrapper, so
      // a square thumbnail crops into a landscape/portrait target instead of
      // stretching.
      fillContent?.frame = aspectFillRect(
        for: start.size,
        in: CGRect(origin: .zero, size: target.size)
      )
      controller.view.alpha = 1
    } completion: { _ in
      controller.pager.alpha = 1

      if fillContent != nil {
        // Snapshot content doesn't match the real image; let the controller
        // crossfade it out once the page's image is actually on screen.
        controller.adoptPresentOverlay(animated)
      } else {
        animated.removeFromSuperview()
      }

      context.completeTransition(!context.transitionWasCancelled)
    }
  }
}

final class GalleryDismissAnimator: NSObject, UIViewControllerAnimatedTransitioning {
  private let session: GallerySession

  init(session: GallerySession) {
    self.session = session
  }

  func transitionDuration(
    using transitionContext: UIViewControllerContextTransitioning?
  ) -> TimeInterval {
    return 0.35
  }

  func animateTransition(using context: UIViewControllerContextTransitioning) {
    guard let controller = context.viewController(forKey: .from) as? GalleryViewController else {
      context.completeTransition(false)
      return
    }

    let container = context.containerView
    let index = controller.currentIndex
    let target = session.dismissTarget(at: index)
    let cell = controller.pager.currentCell

    var animatedView: UIImageView?

    if let cell, let image = cell.currentImage, let frame = cell.imageFrame(in: container) {
      let view = makeTransitionImageView(image: image)
      view.frame = frame
      // Pick up the radius the interactive drag left off at, so the flying
      // copy continues the curve instead of popping back to square.
      view.layer.cornerRadius = cell.dismissCornerRadius
      animatedView = view
    }

    guard let animated = animatedView, let target else {
      let session = self.session

      // The flying copy must be in the hierarchy before the animation block
      // runs, or its property changes apply instantly instead of animating.
      if let animated = animatedView {
        container.addSubview(animated)
        controller.pager.alpha = 0
      }

      UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseIn]) {
        controller.view.alpha = 0

        if let animated = animatedView {
          animated.alpha = 0
          animated.transform = CGAffineTransform(translationX: 0, y: 64)
            .scaledBy(x: 0.92, y: 0.92)
        }
      } completion: { _ in
        animatedView?.removeFromSuperview()
        session.teardown(at: index)
        context.completeTransition(!context.transitionWasCancelled)
      }

      return
    }

    container.addSubview(animated)
    controller.pager.alpha = 0

    let session = self.session

    UIView.animate(
      withDuration: transitionDuration(using: context),
      delay: 0,
      usingSpringWithDamping: 0.9,
      initialSpringVelocity: 0.2
    ) {
      animated.frame = target.rect
      animated.layer.cornerRadius = target.borderRadius
      controller.view.alpha = 0
    } completion: { _ in
      // Linger one beat so a JS-hidden thumbnail can become visible again
      // before the flying copy disappears.
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
        animated.removeFromSuperview()
      }

      session.teardown(at: index)
      context.completeTransition(!context.transitionWasCancelled)
    }
  }
}

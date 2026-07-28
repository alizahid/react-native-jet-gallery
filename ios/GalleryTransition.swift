import SDWebImage
import UIKit

final class GalleryTransitionDelegate: NSObject, UIViewControllerTransitioningDelegate {
  private unowned let session: GallerySession

  init(session: GallerySession) {
    self.session = session
  }

  func animationController(
    forPresented presented: UIViewController,
    presenting: UIViewController,
    source: UIViewController
  ) -> UIViewControllerAnimatedTransitioning? {
    return GalleryPresentAnimator(session: session)
  }

  func animationController(
    forDismissed dismissed: UIViewController
  ) -> UIViewControllerAnimatedTransitioning? {
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

private func cachedImage(for url: String) -> UIImage? {
  guard let parsed = url.hasPrefix("/") ? URL(fileURLWithPath: url) : URL(string: url) else {
    return nil
  }

  guard let key = SDWebImageManager.shared.cacheKey(for: parsed) else {
    return nil
  }

  return SDImageCache.shared.imageFromCache(forKey: key)
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

    if startRect != nil {
      if image != nil {
        animatedView = makeTransitionImageView(image: image)
      } else if let sourceView = session.sourceView,
                let snapshot = sourceView.snapshotView(afterScreenUpdates: false) {
        snapshot.clipsToBounds = true
        snapshot.layer.cornerCurve = .continuous
        animatedView = snapshot
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

    let target = aspectFitRect(
      for: image?.size ?? start.size,
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
      controller.view.alpha = 1
    } completion: { _ in
      controller.pager.alpha = 1
      animated.removeFromSuperview()
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
      animatedView = view
    }

    guard let animated = animatedView, let target else {
      let session = self.session

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

      if let animated = animatedView {
        container.addSubview(animated)
        controller.pager.alpha = 0
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

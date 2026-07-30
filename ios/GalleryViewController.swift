import UIKit

final class GalleryViewController: UIViewController {
  let session: GallerySession

  let dimView = UIView()
  let pager: GalleryPagerView
  private let toolbar: GalleryToolbar
  private let indicator: GalleryPageIndicator

  private(set) var currentIndex: Int

  private var chromeHidden = false
  private var didFireShow = false
  private var presentOverlay: UIView?

  init(session: GallerySession) {
    self.session = session
    self.currentIndex = session.initialIndex
    self.pager = GalleryPagerView(
      urls: session.urls,
      loop: session.loop,
      initialIndex: session.initialIndex
    )
    self.toolbar = GalleryToolbar(actions: session.actions)
    self.indicator = GalleryPageIndicator(
      count: session.urls.count,
      activeColor: session.indicatorColor,
      inactiveColor: session.indicatorInactiveColor
    )

    super.init(nibName: nil, bundle: nil)

    modalPresentationStyle = .custom
    modalPresentationCapturesStatusBarAppearance = true
    transitioningDelegate = session.transition
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var prefersStatusBarHidden: Bool {
    return chromeHidden
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }

  override var prefersHomeIndicatorAutoHidden: Bool {
    return chromeHidden
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = .clear

    dimView.frame = view.bounds
    dimView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    dimView.backgroundColor = session.backgroundColor
    view.addSubview(dimView)

    pager.frame = view.bounds
    pager.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    pager.delegate = self
    view.addSubview(pager)

    toolbar.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(toolbar)

    indicator.translatesAutoresizingMaskIntoConstraints = false
    indicator.isHidden = session.urls.count <= 1
    view.addSubview(indicator)

    NSLayoutConstraint.activate([
      toolbar.topAnchor.constraint(equalTo: view.topAnchor),
      toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 52),
      indicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      indicator.bottomAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.bottomAnchor,
        constant: -16
      ),
      indicator.widthAnchor.constraint(equalToConstant: indicator.intrinsicContentSize.width),
      indicator.heightAnchor.constraint(equalToConstant: indicator.intrinsicContentSize.height),
    ])

    indicator.setProgress(CGFloat(currentIndex))

    toolbar.onClose = { [weak self] in
      self?.dismiss(animated: true)
    }

    toolbar.onAction = { [weak self] id in
      guard let self else {
        return
      }

      self.session.fireAction(id, at: self.currentIndex)
    }

    let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
    pan.delegate = self
    view.addGestureRecognizer(pan)

    pager.panGestureRecognizer.require(toFail: pan)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    if !didFireShow {
      didFireShow = true
      session.fireShow()
    }
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)

    // Safety net for dismissals that bypass the animator (a non-animated
    // dismiss, or the presenting stack being torn down): the thumbnail must
    // be restored and onDismiss must fire. Idempotent after the animated
    // path has already torn down.
    if isBeingDismissed || presentingViewController == nil {
      session.teardown(at: currentIndex)
    }
  }

  // MARK: - Present overlay

  /// Adopts the present transition's flying snapshot so the switch to the
  /// real image is a crossfade instead of a pop. The overlay fades out once
  /// the current page's image loads, the user interacts, or a timeout hits —
  /// whichever comes first.
  func adoptPresentOverlay(_ overlay: UIView) {
    overlay.isUserInteractionEnabled = false
    presentOverlay = overlay
    view.insertSubview(overlay, aboveSubview: pager)

    if pager.currentCell?.currentImage != nil {
      fadePresentOverlay()
    } else {
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
        self?.fadePresentOverlay()
      }
    }
  }

  private func fadePresentOverlay() {
    guard let overlay = presentOverlay else {
      return
    }

    presentOverlay = nil

    UIView.animate(withDuration: 0.18) {
      overlay.alpha = 0
    } completion: { _ in
      overlay.removeFromSuperview()
    }
  }

  private func setChromeHidden(_ hidden: Bool, animated: Bool) {
    chromeHidden = hidden

    UIView.animate(withDuration: animated ? 0.2 : 0) {
      self.toolbar.alpha = hidden ? 0 : 1
      self.indicator.alpha = hidden ? 0 : 1
      self.setNeedsStatusBarAppearanceUpdate()
      self.setNeedsUpdateOfHomeIndicatorAutoHidden()
    }
  }

  // MARK: - Interactive dismiss

  @objc
  private func handlePan(_ pan: UIPanGestureRecognizer) {
    let translation = pan.translation(in: view)

    switch pan.state {
    case .changed:
      fadePresentOverlay()

      let progress = min(max(abs(translation.y) / 320, 0), 1)

      // The thumbnail's radius fades in early (fully in by a third of the
      // drag), so the image already looks like the card it will land on.
      let targetRadius = session.dismissTarget(at: currentIndex)?.borderRadius ?? 0

      pager.currentCell?.setDismissTransform(
        translation: translation,
        scale: 1 - progress * 0.35,
        cornerRadius: min(progress * 3, 1) * targetRadius
      )
      dimView.alpha = 1 - progress * 0.6
      toolbar.alpha = chromeHidden ? 0 : max(1 - progress * 3, 0)
      indicator.alpha = toolbar.alpha

    case .ended, .cancelled:
      let velocity = pan.velocity(in: view)

      if pan.state == .ended, translation.y > 110 || velocity.y > 900 {
        dismiss(animated: true)
      } else {
        UIView.animate(
          withDuration: 0.35,
          delay: 0,
          usingSpringWithDamping: 0.85,
          initialSpringVelocity: 0
        ) {
          self.pager.currentCell?.resetDismissTransform()
          self.dimView.alpha = 1
          self.toolbar.alpha = self.chromeHidden ? 0 : 1
          self.indicator.alpha = self.toolbar.alpha
        }
      }

    default:
      break
    }
  }
}

extension GalleryViewController: UIGestureRecognizerDelegate {
  func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard let pan = gestureRecognizer as? UIPanGestureRecognizer else {
      return true
    }

    if let cell = pager.currentCell, cell.isZoomed {
      return false
    }

    let velocity = pan.velocity(in: view)

    return velocity.y > abs(velocity.x)
  }
}

extension GalleryViewController: GalleryPagerViewDelegate {
  func pager(_ pager: GalleryPagerView, didChangeIndex index: Int) {
    currentIndex = index
    session.fireIndexChange(at: index)
  }

  func pager(_ pager: GalleryPagerView, didScrollToProgress progress: CGFloat) {
    fadePresentOverlay()
    indicator.setProgress(progress)
  }

  func pager(_ pager: GalleryPagerView, didLoadImageAt index: Int) {
    if index == currentIndex {
      fadePresentOverlay()
    }
  }

  func pagerDidSingleTap(_ pager: GalleryPagerView) {
    setChromeHidden(!chromeHidden, animated: true)
  }
}

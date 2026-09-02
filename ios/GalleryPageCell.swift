import SDWebImage
import UIKit

final class GalleryPageCell: UICollectionViewCell {
  static let reuseIdentifier = "GalleryPageCell"

  /// Decode capped at 2× screen pixels per axis — enough headroom for zooming
  /// without holding full-resolution bitmaps for every page. The transition's
  /// cache lookup must pass the same context, since the thumbnail size is part
  /// of the cache key.
  static let decodeContext: [SDWebImageContextOption: Any] = [
    .imageThumbnailPixelSize: CGSize(
      width: UIScreen.main.bounds.width * UIScreen.main.scale * 2,
      height: UIScreen.main.bounds.height * UIScreen.main.scale * 2
    ),
    // Decode GIFs as SDAnimatedImage so the page's view drives them with a
    // seekable player (sd_setImage adds this implicitly; the manual manager
    // load below does not). A plain frame-array UIImage always restarts at 0.
    .animatedImageClass: SDAnimatedImage.self,
  ]

  var onSingleTap: (() -> Void)?
  var onImageLoad: (() -> Void)?

  private let scrollView = UIScrollView()
  private let imageView = SDAnimatedImageView()

  private var imageSize: CGSize = .zero
  private var loadOperation: SDWebImageCombinedOperation?

  override init(frame: CGRect) {
    super.init(frame: frame)

    scrollView.showsVerticalScrollIndicator = false
    scrollView.showsHorizontalScrollIndicator = false
    scrollView.contentInsetAdjustmentBehavior = .never
    scrollView.bouncesZoom = true
    scrollView.delegate = self
    contentView.addSubview(scrollView)

    imageView.contentMode = .scaleAspectFill
    imageView.clipsToBounds = true
    imageView.layer.cornerCurve = .continuous
    scrollView.addSubview(imageView)

    let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
    doubleTap.numberOfTapsRequired = 2
    scrollView.addGestureRecognizer(doubleTap)

    let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
    singleTap.require(toFail: doubleTap)
    scrollView.addGestureRecognizer(singleTap)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func prepareForReuse() {
    super.prepareForReuse()

    loadOperation?.cancel()
    loadOperation = nil
    imageView.image = nil
    imageView.transform = .identity
    imageView.layer.cornerRadius = 0
    dismissCornerRadius = 0
    imageSize = .zero
    onSingleTap = nil
    onImageLoad = nil

    // Clear zoom state so a reused cell whose image is still loading doesn't
    // report isZoomed and block the pan-to-dismiss gesture.
    scrollView.minimumZoomScale = 1
    scrollView.maximumZoomScale = 1
    scrollView.zoomScale = 1
    scrollView.contentSize = .zero
    scrollView.contentInset = .zero
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    let frame = contentView.bounds.insetBy(dx: GalleryPagerView.pageGap / 2, dy: 0)

    if scrollView.frame != frame {
      scrollView.frame = frame
      layoutImage()
    }
  }

  /// `placeholder` is an already-decoded bitmap (the thumbnail, or the full
  /// image from another cache client) shown aspect-fit until the load lands,
  /// so the page matches the open transition's final frame pixel for pixel.
  func configure(url: String, placeholder: GalleryPlaceholder?) {
    loadOperation?.cancel()
    loadOperation = nil

    imageSize = placeholder?.image.size ?? .zero
    imageView.transform = .identity
    imageView.layer.cornerRadius = 0
    dismissCornerRadius = 0

    if let placeholder {
      imageView.image = placeholder.image
      imageView.seek(to: placeholder.frame)
      layoutImage()

      // The full image is already decoded: adopt it rather than decoding a
      // second copy, which would also restart a GIF from frame 0.
      if placeholder.isFull {
        return
      }
    } else {
      imageView.image = nil
    }

    let parsed = url.hasPrefix("/") ? URL(fileURLWithPath: url) : URL(string: url)

    // Loaded through the manager rather than sd_setImage so the swap is ours:
    // the placeholder's GIF position is read right before the full image
    // replaces it, and carried over when both are the same animation.
    loadOperation = SDWebImageManager.shared.loadImage(
      with: parsed,
      options: [.retryFailed],
      context: Self.decodeContext,
      progress: nil
    ) { [weak self] image, _, _, _, finished, _ in
      guard let self, let image, finished else {
        return
      }

      let position = self.imageView.framePosition

      self.imageView.image = image
      self.imageView.seek(to: position)
      self.imageSize = image.size
      self.layoutImage()
      self.onImageLoad?()
    }
  }

  private func layoutImage() {
    guard imageSize.width > 0, imageSize.height > 0,
          scrollView.bounds.width > 0, scrollView.bounds.height > 0 else {
      return
    }

    let bounds = scrollView.bounds.size
    let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
    let fitted = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)

    scrollView.minimumZoomScale = 1
    scrollView.zoomScale = 1
    scrollView.maximumZoomScale = max(2.5, 1 / max(scale, 0.001) / UIScreen.main.scale * 1.1)

    imageView.frame = CGRect(origin: .zero, size: fitted)
    scrollView.contentSize = fitted

    centerImage()
  }

  private func centerImage() {
    let bounds = scrollView.bounds.size
    let content = scrollView.contentSize

    scrollView.contentInset = UIEdgeInsets(
      top: max((bounds.height - content.height) / 2, 0),
      left: max((bounds.width - content.width) / 2, 0),
      bottom: 0,
      right: 0
    )
  }

  var isZoomed: Bool {
    return scrollView.zoomScale > scrollView.minimumZoomScale + 0.01
  }

  func resetZoom(animated: Bool) {
    scrollView.setZoomScale(scrollView.minimumZoomScale, animated: animated)
  }

  var currentImage: UIImage? {
    return imageView.image
  }

  /// Where the page's GIF is in its loop, for the dismiss copy to continue from.
  var framePosition: GalleryFramePosition? {
    return imageView.framePosition
  }

  /// The image's current frame (including any interactive transform) in `view` coordinates.
  func imageFrame(in view: UIView) -> CGRect? {
    guard imageView.window != nil, imageView.image != nil else {
      return nil
    }

    return imageView.convert(imageView.bounds, to: view)
  }

  /// Visual corner radius applied by the interactive drag, for the dismiss
  /// animator to start its flying copy from.
  private(set) var dismissCornerRadius: CGFloat = 0

  func setDismissTransform(translation: CGPoint, scale: CGFloat, cornerRadius: CGFloat) {
    dismissCornerRadius = cornerRadius

    imageView.transform = CGAffineTransform(translationX: translation.x, y: translation.y)
      .scaledBy(x: scale, y: scale)
    // The transform scales the layer's radius too, so divide to keep the
    // on-screen radius equal to cornerRadius.
    imageView.layer.cornerRadius = scale > 0 ? cornerRadius / scale : cornerRadius
  }

  func resetDismissTransform() {
    dismissCornerRadius = 0
    imageView.transform = .identity
    imageView.layer.cornerRadius = 0
  }

  @objc
  private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
    if isZoomed {
      resetZoom(animated: true)
    } else {
      let point = recognizer.location(in: imageView)
      let scale = min(scrollView.maximumZoomScale, max(scrollView.minimumZoomScale * 2.5, 2))
      let size = CGSize(
        width: scrollView.bounds.width / scale,
        height: scrollView.bounds.height / scale
      )

      scrollView.zoom(
        to: CGRect(
          x: point.x - size.width / 2,
          y: point.y - size.height / 2,
          width: size.width,
          height: size.height
        ),
        animated: true
      )
    }
  }

  @objc
  private func handleSingleTap() {
    onSingleTap?()
  }
}

extension GalleryPageCell: UIScrollViewDelegate {
  func viewForZooming(in scrollView: UIScrollView) -> UIView? {
    return imageView
  }

  func scrollViewDidZoom(_ scrollView: UIScrollView) {
    centerImage()
  }
}

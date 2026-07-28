import SDWebImage
import UIKit

final class GalleryPageCell: UICollectionViewCell {
  static let reuseIdentifier = "GalleryPageCell"

  var onSingleTap: (() -> Void)?

  private let scrollView = UIScrollView()
  private let imageView = SDAnimatedImageView()

  private var imageSize: CGSize = .zero

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

    imageView.sd_cancelCurrentImageLoad()
    imageView.image = nil
    imageView.transform = .identity
    imageSize = .zero
    onSingleTap = nil
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    let frame = contentView.bounds.insetBy(dx: GalleryPagerView.pageGap / 2, dy: 0)

    if scrollView.frame != frame {
      scrollView.frame = frame
      layoutImage()
    }
  }

  func configure(url: String) {
    imageSize = .zero
    imageView.transform = .identity

    let parsed = url.hasPrefix("/") ? URL(fileURLWithPath: url) : URL(string: url)

    imageView.sd_setImage(with: parsed, placeholderImage: nil, options: [.retryFailed]) {
      [weak self] image, _, _, _ in
      guard let self, let image else {
        return
      }

      self.imageSize = image.size
      self.layoutImage()
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

  /// The image's current frame (including any interactive transform) in `view` coordinates.
  func imageFrame(in view: UIView) -> CGRect? {
    guard imageView.window != nil, imageView.image != nil else {
      return nil
    }

    return imageView.convert(imageView.bounds, to: view)
  }

  func setDismissTransform(translation: CGPoint, scale: CGFloat) {
    imageView.transform = CGAffineTransform(translationX: translation.x, y: translation.y)
      .scaledBy(x: scale, y: scale)
  }

  func resetDismissTransform() {
    imageView.transform = .identity
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

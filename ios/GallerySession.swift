import SDWebImage
import UIKit

struct GalleryDismissTarget {
  let rect: CGRect
  let borderRadius: CGFloat
}

extension GalleryDismissTarget {
  /// Rejects rects with non-finite values coming across the JS bridge —
  /// NaN geometry raises CALayerInvalidGeometry when set as a frame.
  init?(_ rect: TransitionRect) {
    guard rect.x.isFinite, rect.y.isFinite, rect.width.isFinite, rect.height.isFinite else {
      return nil
    }

    let radius = rect.borderRadius ?? 0

    self.init(
      rect: CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height),
      borderRadius: radius.isFinite ? CGFloat(radius) : 0
    )
  }
}

extension Double {
  /// Double→Int that returns nil instead of trapping on NaN, ±∞, or overflow.
  var asSafeInt: Int? {
    return Int(exactly: rounded())
  }
}

struct GalleryActionItem {
  let id: String
  let title: String?
  let icon: String
}

/// Holds the options, callbacks, and mutable state for one gallery presentation.
final class GallerySession {
  let urls: [String]
  let initialIndex: Int
  let loop: Bool
  let actions: [GalleryActionItem]
  let backgroundColor: UIColor
  let indicatorColor: UIColor
  let indicatorInactiveColor: UIColor
  let origin: GalleryDismissTarget?

  private let sourceTag: Double?
  private(set) weak var sourceView: UIView?
  private var sourceViewAlpha: CGFloat = 1

  var dismissTargets: [Int: GalleryDismissTarget] = [:]

  private var onShow: (() -> Void)?
  private var onIndexChange: ((GalleryEventPayload) -> Void)?
  private var onAction: ((GalleryActionPayload) -> Void)?
  private var onDismiss: ((GalleryEventPayload) -> Void)?

  var onTeardown: (() -> Void)?

  private(set) lazy var transition = GalleryTransitionDelegate(session: self)

  private var didTeardown = false

  init(options: GalleryOpenOptions) {
    let urls = options.urls

    self.urls = urls
    self.initialIndex = min(max(options.initialIndex?.asSafeInt ?? 0, 0), max(urls.count - 1, 0))
    self.loop = options.loop ?? false
    self.actions = (options.actions ?? []).map {
      GalleryActionItem(id: $0.id, title: $0.title, icon: $0.icon)
    }
    self.backgroundColor = UIColor(hexString: options.backgroundColor) ?? .black
    self.indicatorColor = UIColor(hexString: options.indicatorColor) ?? .white
    self.indicatorInactiveColor =
      UIColor(hexString: options.indicatorInactiveColor) ?? UIColor.white.withAlphaComponent(0.4)
    self.origin = options.origin.flatMap { GalleryDismissTarget($0) }
    self.sourceTag = options.sourceTag
    self.onShow = options.onShow
    self.onIndexChange = options.onIndexChange
    self.onAction = options.onAction
    self.onDismiss = options.onDismiss
  }

  func url(at index: Int) -> String {
    guard urls.indices.contains(index) else {
      return ""
    }

    return urls[index]
  }

  private func payload(at index: Int) -> GalleryEventPayload {
    return GalleryEventPayload(index: Double(index), url: url(at: index))
  }

  /// Main thread only. Resolves the React thumbnail view from its tag.
  func resolveSourceView() {
    guard let tag = sourceTag?.asSafeInt, tag > 0 else {
      return
    }

    sourceView = GallerySourceViewFinder.find(tag: tag)
  }

  func hideSourceView() {
    guard let view = sourceView else {
      return
    }

    sourceViewAlpha = view.alpha
    view.alpha = 0
  }

  func restoreSourceView() {
    sourceView?.alpha = sourceViewAlpha
  }

  /// The rect the dismiss animation should land on for `index`, if any.
  func dismissTarget(at index: Int) -> GalleryDismissTarget? {
    if let target = dismissTargets[index] {
      return target
    }

    guard index == initialIndex else {
      return nil
    }

    if let view = sourceView, view.window != nil {
      return GalleryDismissTarget(
        rect: view.convert(view.bounds, to: nil),
        borderRadius: view.layer.cornerRadius
      )
    }

    return origin
  }

  func fireShow() {
    onShow?()
  }

  func fireIndexChange(at index: Int) {
    onIndexChange?(payload(at: index))
  }

  func fireAction(_ id: String, at index: Int) {
    onAction?(GalleryActionPayload(actionId: id, index: Double(index), url: url(at: index)))
  }

  /// Restores the thumbnail, fires onDismiss, and releases all JS callbacks.
  func teardown(at index: Int) {
    guard !didTeardown else {
      return
    }

    didTeardown = true

    restoreSourceView()

    let dismiss = onDismiss
    let payload = payload(at: index)

    onShow = nil
    onIndexChange = nil
    onAction = nil
    onDismiss = nil

    onTeardown?()
    onTeardown = nil

    dismiss?(payload)
  }
}

extension UIColor {
  convenience init?(hexString: String?) {
    guard var hex = hexString?.trimmingCharacters(in: .whitespacesAndNewlines) else {
      return nil
    }

    if hex.hasPrefix("#") {
      hex.removeFirst()
    }

    if hex.count == 6 {
      hex += "FF"
    }

    guard hex.count == 8, let value = UInt64(hex, radix: 16) else {
      return nil
    }

    self.init(
      red: CGFloat((value >> 24) & 0xff) / 255,
      green: CGFloat((value >> 16) & 0xff) / 255,
      blue: CGFloat((value >> 8) & 0xff) / 255,
      alpha: CGFloat(value & 0xff) / 255
    )
  }
}

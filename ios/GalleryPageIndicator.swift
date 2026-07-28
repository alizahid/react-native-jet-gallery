import UIKit

/// A dot page indicator whose active bullet is a double-width pill. Driven by
/// a fractional page progress so the pill hands off smoothly between bullets
/// while the user is dragging, including across the loop seam.
final class GalleryPageIndicator: UIView {
  private let count: Int
  private let activeColor: UIColor
  private let inactiveColor: UIColor

  private let dotSize: CGFloat = 6
  private let activeWidth: CGFloat = 12
  private let spacing: CGFloat = 6

  private var dots: [UIView] = []

  /// Fractional page position in `[0, count)`.
  private var progress: CGFloat = 0

  init(count: Int, activeColor: UIColor, inactiveColor: UIColor) {
    self.count = count
    self.activeColor = activeColor
    self.inactiveColor = inactiveColor

    super.init(frame: .zero)

    isUserInteractionEnabled = false

    for _ in 0..<count {
      let dot = UIView()

      dot.layer.cornerRadius = dotSize / 2
      dot.layer.cornerCurve = .continuous
      addSubview(dot)
      dots.append(dot)
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var intrinsicContentSize: CGSize {
    let width = CGFloat(count - 1) * (dotSize + spacing) + activeWidth

    return CGSize(width: width, height: dotSize)
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    layoutDots()
  }

  func setProgress(_ value: CGFloat) {
    guard count > 1, value.isFinite else {
      return
    }

    progress = value.truncatingRemainder(dividingBy: CGFloat(count))

    if progress < 0 {
      progress += CGFloat(count)
    }

    layoutDots()
  }

  private func layoutDots() {
    guard count > 0 else {
      return
    }

    let current = min(Int(floor(progress)), count - 1)
    let next = (current + 1) % count
    let fraction = progress - floor(progress)

    var weights = [CGFloat](repeating: 0, count: count)
    weights[current] = 1 - fraction
    weights[next] += fraction

    // Weights always sum to 1, so the row keeps a constant total width.
    var x = bounds.midX - intrinsicContentSize.width / 2
    let y = bounds.midY - dotSize / 2

    for (index, dot) in dots.enumerated() {
      let weight = weights[index]
      let width = dotSize + (activeWidth - dotSize) * weight

      dot.frame = CGRect(x: x, y: y, width: width, height: dotSize)
      dot.backgroundColor = blend(inactiveColor, activeColor, weight)

      x += width + spacing
    }
  }

  private func blend(_ from: UIColor, _ to: UIColor, _ amount: CGFloat) -> UIColor {
    var fromRed: CGFloat = 0, fromGreen: CGFloat = 0, fromBlue: CGFloat = 0, fromAlpha: CGFloat = 0
    var toRed: CGFloat = 0, toGreen: CGFloat = 0, toBlue: CGFloat = 0, toAlpha: CGFloat = 0

    from.getRed(&fromRed, green: &fromGreen, blue: &fromBlue, alpha: &fromAlpha)
    to.getRed(&toRed, green: &toGreen, blue: &toBlue, alpha: &toAlpha)

    return UIColor(
      red: fromRed + (toRed - fromRed) * amount,
      green: fromGreen + (toGreen - fromGreen) * amount,
      blue: fromBlue + (toBlue - fromBlue) * amount,
      alpha: fromAlpha + (toAlpha - fromAlpha) * amount
    )
  }
}

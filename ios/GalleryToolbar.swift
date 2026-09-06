import UIKit

final class GalleryToolbar: UIView {
  var onClose: (() -> Void)?
  var onAction: ((String) -> Void)?

  private let gradient = CAGradientLayer()

  init(actions: [GalleryActionItem]) {
    super.init(frame: .zero)

    // Liquid Glass carries its own contrast; the scrim is only for older iOS.
    if #unavailable(iOS 26) {
      gradient.colors = [
        UIColor.black.withAlphaComponent(0.6).cgColor,
        UIColor.black.withAlphaComponent(0).cgColor,
      ]
      layer.addSublayer(gradient)
    }

    let close = glass(
      makeButton(icon: "xmark", label: "Close") { [weak self] in
        self?.onClose?()
      }
    )

    addSubview(close)

    let stack = UIStackView()
    stack.axis = .horizontal
    stack.translatesAutoresizingMaskIntoConstraints = false

    for action in actions {
      let button = makeButton(icon: action.icon, label: action.title ?? action.id) { [weak self] in
        self?.onAction?(action.id)
      }

      stack.addArrangedSubview(button)
    }

    let group = glass(stack)
    addSubview(group)

    NSLayoutConstraint.activate([
      close.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
      close.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
      group.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
      group.centerYAnchor.constraint(equalTo: close.centerYAnchor),
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    gradient.frame = CGRect(
      x: 0,
      y: 0,
      width: bounds.width,
      height: bounds.height + 40
    )
  }

  private func makeButton(icon: String, label: String, handler: @escaping () -> Void) -> UIButton {
    // Configuration-based layout centers the symbol; the legacy `.system` layout
    // baseline-aligns it to the empty title and it sits visibly low.
    var config = UIButton.Configuration.plain()
    config.image = UIImage(systemName: icon)
    config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
    config.baseForegroundColor = .white
    config.contentInsets = .zero

    let button = UIButton(configuration: config)
    button.addAction(UIAction { _ in handler() }, for: .primaryActionTriggered)
    button.accessibilityLabel = label
    button.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      button.widthAnchor.constraint(equalToConstant: 44),
      button.heightAnchor.constraint(equalToConstant: 44),
    ])

    return button
  }

  /// Wraps `content` in a Liquid Glass capsule on iOS 26; passes it through otherwise.
  private func glass(_ content: UIView) -> UIView {
    guard #available(iOS 26, *) else { return content }

    let effect = UIGlassEffect(style: .regular)
    effect.isInteractive = true

    let effectView = UIVisualEffectView(effect: effect)
    effectView.cornerConfiguration = .capsule()
    effectView.translatesAutoresizingMaskIntoConstraints = false
    effectView.contentView.addSubview(content)

    NSLayoutConstraint.activate([
      content.topAnchor.constraint(equalTo: effectView.contentView.topAnchor),
      content.bottomAnchor.constraint(equalTo: effectView.contentView.bottomAnchor),
      content.leadingAnchor.constraint(equalTo: effectView.contentView.leadingAnchor),
      content.trailingAnchor.constraint(equalTo: effectView.contentView.trailingAnchor),
    ])

    return effectView
  }
}

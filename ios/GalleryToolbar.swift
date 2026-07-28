import UIKit

final class GalleryToolbar: UIView {
  var onClose: (() -> Void)?
  var onAction: ((String) -> Void)?

  private let gradient = CAGradientLayer()

  init(actions: [GalleryActionItem]) {
    super.init(frame: .zero)

    gradient.colors = [
      UIColor.black.withAlphaComponent(0.6).cgColor,
      UIColor.black.withAlphaComponent(0).cgColor,
    ]
    layer.addSublayer(gradient)

    let close = makeButton(icon: "xmark", label: "Close")

    close.addAction(
      UIAction { [weak self] _ in
        self?.onClose?()
      },
      for: .primaryActionTriggered
    )

    addSubview(close)

    let stack = UIStackView()
    stack.axis = .horizontal
    stack.spacing = 4
    stack.translatesAutoresizingMaskIntoConstraints = false
    addSubview(stack)

    for action in actions {
      let button = makeButton(icon: action.icon, label: action.title ?? action.id)

      button.addAction(
        UIAction { [weak self] _ in
          self?.onAction?(action.id)
        },
        for: .primaryActionTriggered
      )

      stack.addArrangedSubview(button)
    }

    NSLayoutConstraint.activate([
      close.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
      close.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
      stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
      stack.centerYAnchor.constraint(equalTo: close.centerYAnchor),
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

  private func makeButton(icon: String, label: String) -> UIButton {
    let button = UIButton(type: .system)

    button.setImage(
      UIImage(
        systemName: icon,
        withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
      ),
      for: .normal
    )
    button.tintColor = .white
    button.accessibilityLabel = label
    button.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      button.widthAnchor.constraint(equalToConstant: 44),
      button.heightAnchor.constraint(equalToConstant: 44),
    ])

    return button
  }
}

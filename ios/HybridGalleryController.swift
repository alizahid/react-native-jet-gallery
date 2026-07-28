import Foundation
import UIKit

class HybridGalleryController: HybridGalleryControllerSpec {
  private var session: GallerySession?
  private weak var presentedController: GalleryViewController?

  var isVisible: Bool {
    return session != nil
  }

  func open(options: GalleryOpenOptions) throws {
    guard !options.urls.isEmpty else {
      return
    }

    let session = GallerySession(options: options)

    DispatchQueue.main.async { [weak self] in
      guard let self else {
        return
      }

      if let existing = self.session {
        guard self.presentedController == nil else {
          return
        }

        // Self-heal: a session without a live view controller can never
        // dismiss on its own, and would block every future open().
        existing.teardown(at: existing.initialIndex)
      }

      self.session = session

      session.onTeardown = { [weak self] in
        self?.session = nil
      }

      self.present(session)
    }
  }

  func close() throws {
    DispatchQueue.main.async { [weak self] in
      self?.presentedController?.dismiss(animated: true)
    }
  }

  func setDismissTarget(index: Double, rect: TransitionRect?) throws {
    let target = rect.map {
      GalleryDismissTarget(
        rect: CGRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height),
        borderRadius: CGFloat($0.borderRadius ?? 0)
      )
    }

    DispatchQueue.main.async { [weak self] in
      self?.session?.dismissTargets[Int(index)] = target
    }
  }

  private func present(_ session: GallerySession) {
    session.resolveSourceView()

    guard let presenter = Self.topViewController() else {
      session.teardown(at: session.initialIndex)
      return
    }

    let controller = GalleryViewController(session: session)
    presentedController = controller

    presenter.present(controller, animated: true)
  }

  private static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let windows = scenes.flatMap(\.windows)
    let window = windows.first { $0.isKeyWindow } ?? windows.first

    var top = window?.rootViewController

    while let presented = top?.presentedViewController {
      top = presented
    }

    return top
  }
}

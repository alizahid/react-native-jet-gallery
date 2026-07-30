import Foundation
import UIKit

class HybridGalleryController: HybridGalleryControllerSpec {
  /// Main thread only.
  private var session: GallerySession?
  private weak var presentedController: GalleryViewController?

  /// Mirror of `session != nil`. `session` itself is confined to the main
  /// thread, but `isVisible` is read from the JS thread.
  private let visibleLock = NSLock()
  private var visible = false

  var isVisible: Bool {
    visibleLock.lock()
    defer { visibleLock.unlock() }
    return visible
  }

  private func setSession(_ session: GallerySession?) {
    self.session = session

    visibleLock.lock()
    visible = session != nil
    visibleLock.unlock()
  }

  func open(options: GalleryOpenOptions) throws {
    guard !options.images.isEmpty else {
      options.onDismiss?(GalleryEventPayload(index: 0, url: ""))
      return
    }

    let session = GallerySession(options: options)

    DispatchQueue.main.async { [weak self] in
      guard let self else {
        return
      }

      if let existing = self.session {
        guard self.presentedController == nil else {
          // A gallery is already on screen; reject the new session, but fire
          // its onDismiss so the JS side isn't left waiting forever.
          session.teardown(at: session.initialIndex)
          return
        }

        // Self-heal: a session without a live view controller can never
        // dismiss on its own, and would block every future open().
        existing.teardown(at: existing.initialIndex)
      }

      self.setSession(session)

      session.onTeardown = { [weak self] in
        self?.setSession(nil)
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
    guard let index = index.asSafeInt else {
      return
    }

    // An invalid rect clears the target, falling back to the fade dismiss.
    let target = rect.flatMap { GalleryDismissTarget($0) }

    DispatchQueue.main.async { [weak self] in
      self?.session?.dismissTargets[index] = target
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

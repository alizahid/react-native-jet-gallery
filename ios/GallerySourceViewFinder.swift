import UIKit

enum GallerySourceViewFinder {
  /// Fabric mounts component views with `UIView.tag` set to the React tag,
  /// so a plain recursive tag search finds the thumbnail's host view.
  static func find(tag: Int) -> UIView? {
    guard tag != 0 else {
      return nil
    }

    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }

    for scene in scenes {
      for window in scene.windows {
        if let view = window.viewWithTag(tag) {
          return view
        }
      }
    }

    return nil
  }
}

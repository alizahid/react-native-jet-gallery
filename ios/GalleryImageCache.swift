import SDWebImage
import UIKit

/// Bridges to bitmaps the app has already decoded, so the open transition
/// and the first page can show real pixels before the full image loads.
enum GalleryImageCache {
  /// Memory-only lookup in the shared SDWebImage cache.
  ///
  /// Checks the key this library decodes under (thumbnail-sized) and the
  /// plain URL key that expo-image and other SDWebImage clients use, so an
  /// image already on screen elsewhere in the app is reused instead of
  /// re-decoded. Memory only: a disk hit would decode synchronously on the
  /// main thread right as the transition starts.
  static func memoryImage(for url: String?) -> UIImage? {
    guard let url, !url.isEmpty,
          let parsed = url.hasPrefix("/") ? URL(fileURLWithPath: url) : URL(string: url) else {
      return nil
    }

    let manager = SDWebImageManager.shared

    var keys: [String] = []

    if let key = manager.cacheKey(for: parsed, context: GalleryPageCell.decodeContext) {
      keys.append(key)
    }

    if let key = manager.cacheKey(for: parsed) {
      keys.append(key)
    }

    // expo-image builds its own manager without a key filter, so its key is
    // the bare absolute string.
    keys.append(parsed.absoluteString)

    var seen = Set<String>()

    for key in keys where seen.insert(key).inserted {
      if let image = SDImageCache.shared.imageFromMemoryCache(forKey: key) {
        return image
      }
    }

    return nil
  }

  /// The image view a thumbnail is rendering with, found by walking its
  /// subviews for the largest image view with an image. Reads the rendered
  /// view rather than a cache, so it works with any image library and with
  /// thumbnails whose URL the gallery doesn't know. expo-image renders into
  /// an SDAnimatedImageView, which also exposes where its GIF is in its loop.
  static func displayedImageView(in view: UIView) -> UIImageView? {
    var queue: [UIView] = [view]
    var best: UIImageView?

    while !queue.isEmpty {
      let current = queue.removeFirst()

      if let imageView = current as? UIImageView, let image = imageView.image,
         image.size.width > 0, image.size.height > 0 {
        let area = image.size.width * image.size.height
        let bestArea = best?.image.map { $0.size.width * $0.size.height } ?? 0

        if area > bestArea {
          best = imageView
        }
      }

      queue.append(contentsOf: current.subviews)
    }

    return best
  }
}

/// Where an animated image is in its loop. Handed from one image view to the
/// next so a GIF keeps its timing across the thumbnail, the flying copy, and
/// the page instead of restarting from frame 0 in each new instance.
struct GalleryFramePosition {
  let index: UInt
  let loopCount: UInt
  let frameCount: UInt
}

extension SDAnimatedImageView {
  var framePosition: GalleryFramePosition? {
    guard let player, player.totalFrameCount > 1 else {
      return nil
    }

    return GalleryFramePosition(
      index: player.currentFrameIndex,
      loopCount: player.currentLoopCount,
      frameCount: player.totalFrameCount
    )
  }

  /// Seeks to `position` when this view is playing the same animation (same
  /// frame count); a different image keeps its own timing. Call after the
  /// image is set and the view is in a window so the player exists.
  func seek(to position: GalleryFramePosition?) {
    guard let position, let player, player.totalFrameCount == position.frameCount,
          position.index < player.totalFrameCount else {
      return
    }

    player.seekToFrame(at: position.index, loopCount: position.loopCount)
  }
}

extension UIImageView {
  var galleryFramePosition: GalleryFramePosition? {
    return (self as? SDAnimatedImageView)?.framePosition
  }
}

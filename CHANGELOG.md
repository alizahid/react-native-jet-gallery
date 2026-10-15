# Changelog

## [1.1.1](https://github.com/alizahid/react-native-jet-gallery/compare/v1.1.0...v1.1.1) (2026-10-14)

### Bug Fixes

* decode the GIF resume frame off the main thread on open ([bc18fc4](https://github.com/alizahid/react-native-jet-gallery/commit/bc18fc4476656275a65c0f416ccd1686659ae93d))

## 1.1.0

### Fixed

- The toolbar now follows the system layout margins and the corner-adapted safe area, so its buttons no longer sit under the side status bar or hug the top edge on iPhone Duo. On other iPhones the buttons sit 16pt from the edges (was 12pt).

### Compatibility

- No breaking changes from 1.0.0.

## 1.0.0

The first stable release. Everything since 0.1.0-beta.0, curated:

### Transitions

- Images are `{ url, thumbnail?, width?, height? }`. With `width` and `height`, the open transition lands on the image's real aspect ratio before it has loaded; the flying copy crops inside a clipping wrapper instead of stretching.
- The open transition and the first page use the best bitmap already decoded: the full image from the shared SDWebImage memory cache, else `thumbnail`, else the pixels the pressed view is rendering. The page is seeded with the same bitmap, so the copy lands on identical pixels instead of popping.
- Imperative opens with an `origin` snapshot that rect when the cache is cold, instead of degrading to a fade.
- Corner radius animates: it ramps in during the interactive pan, carries into the dismiss flight, and springs back on cancel. `Gallery.Image` forwards a uniform numeric `borderRadius` from its style.
- GIFs keep their frame position across every handoff: thumbnail to flying copy to page on open, placeholder to full image on load, and back on dismiss.
- The flying copy passes beneath the toolbar and page indicator, so a tall image no longer covers the buttons mid-flight.
- Paging away from the pressed thumbnail restores it, so a dismiss at another index only hides that page's thumbnail.

### Toolbar and viewer

- The toolbar is tappable from the first frame of the open transition. A close tapped mid-flight, or a `Gallery.close()` called during it, is honored once presentation completes.
- On iOS 26, close and the action group are Liquid Glass capsules (the gradient scrim remains on older iOS). SF Symbols are centered in their buttons.
- The viewer rotates with the device within the orientations the app allows. `rotation: false` keeps the orientation it opened in.
- The page indicator is hidden above 20 images.
- VoiceOver: the viewer is modal and the escape gesture dismisses it.

### Pressables

- `Gallery.Image` renders react-native-gesture-handler's `Pressable`, so thumbnails keep working inside gesture-handler pressables and touchables. The innermost pressable wins.
- New `onLongPress` prop on `Gallery.Image`.

### Images and memory

- Pages decode at up to 1.5x screen pixels per axis instead of full resolution, and the pages either side of the current one are prefetched into the shared cache.
- The present transition only looks up the memory cache, so it never decodes from disk on the main thread.
- A `Gallery.Image` re-renders only when its own hidden state changes.

### Fixes

- Non-finite numbers and rects from JS no longer crash on the native side.
- Fixed a data race on `isVisible` between the JS and main threads.
- Non-animated dismissals restore the thumbnail and fire `onDismiss`.
- Rejected opens (empty `images`, or a gallery already open) fire `onDismiss`.
- A page left zoomed by a recycled cell no longer blocks pan-to-dismiss.
- The fallback dismiss fades its flying image out instead of blinking.
- The current page stays aligned when the bounds change.

### Breaking changes since 0.1.0-beta.0

- `Gallery` and `Gallery.open` take `images` instead of `urls`.
- `react-native-gesture-handler` is a required peer dependency, and the app must be wrapped in a `GestureHandlerRootView`.
- iOS 16.4 minimum, built with Xcode 26.

## 0.1.0-beta.0

Initial release (iOS).

- `<Gallery>` and `<Gallery.Image>` wrap any image component with a shared-element open and dismiss transition.
- `Gallery.open` with an optional origin rect, `Gallery.close`, and `Gallery.isVisible`.
- Paging with optional infinite looping, pinch and double-tap zoom, and swipe-down to dismiss that lands on the current image's thumbnail.
- Animated GIF playback via SDWebImage.
- Custom SF Symbol toolbar actions and an animated page indicator with configurable colors.

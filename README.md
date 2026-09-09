<p align="center">
  <img alt="react-native-jet-gallery — native photo gallery with shared-element transitions for React Native" src="https://raw.githubusercontent.com/alizahid/react-native-jet-gallery/main/docs/hero.svg" width="900">
</p>

<p align="center">
  Native photo gallery with shared-element transitions, looping, GIFs, and custom actions — powered by <a href="https://nitro.margelo.com">Nitro Modules</a>
</p>

<p align="center">
  <a href="https://www.npmjs.com/package/react-native-jet-gallery"><img src="https://img.shields.io/npm/v/react-native-jet-gallery?color=A02F6F&label=npm" alt="npm"></a>
  <a href="https://github.com/alizahid/react-native-jet-gallery/blob/main/LICENSE"><img src="https://img.shields.io/npm/l/react-native-jet-gallery?color=668C0B" alt="license"></a>
  <img src="https://img.shields.io/badge/platform-iOS-5E409D" alt="platform">
  <img src="https://img.shields.io/badge/powered%20by-Nitro%20Modules-205EA6" alt="nitro modules">
</p>

---

## Features

- **Wrap your own image component** — expo-image, `Image`, anything — and get a fullscreen viewer with a shared-element open and dismiss transition
- **Imperative API** to open the gallery from anywhere, with a transition when you pass an origin rect
- **Paging** with optional infinite **looping**, and adjacent pages prefetched
- **Pinch** and **double-tap zoom**
- **Swipe down to dismiss** that follows your finger and lands on the correct thumbnail, even after paging
- Animated **GIF, APNG, and WebP** playback, with GIFs keeping their timing across the transition
- **Custom actions** as SF Symbol toolbar buttons, Liquid Glass on iOS 26
- Animated **page indicator** whose active pill follows your finger
- **Rotates** with the device
- VoiceOver: modal focus and the escape gesture dismisses

## Requirements

- iOS 16.4+, built with Xcode 26
- A development build — Nitro Modules do not work in Expo Go
- Your app wrapped in a `GestureHandlerRootView` (expo-router and react-navigation apps already are)
- Android is not supported yet; every call is a safe no-op there

## Installation

```sh
npm install react-native-jet-gallery react-native-nitro-modules react-native-gesture-handler
cd ios && pod install
```

With Expo, `npx expo prebuild` handles the pod install and [react-native-gesture-handler](https://docs.swmansion.com/react-native-gesture-handler/) is already part of every project.

## Usage

### Declarative

Wrap your thumbnails in `Gallery.Image`. Each one becomes a pressable that opens the viewer with a transition from its exact frame, and dismissing transitions back to the thumbnail of whichever image you are on.

```tsx
import { Image } from 'expo-image'
import { Gallery } from 'react-native-jet-gallery'

const images = [
  { url: 'https://example.com/1.jpg', width: 1200, height: 800 },
  { url: 'https://example.com/2.gif' },
]

function Grid() {
  return (
    <Gallery
      actions={[
        {
          icon: 'square.and.arrow.down',
          id: 'save',
          onPress: (payload) => save(payload.url),
          title: 'Save',
        },
      ]}
      images={images}
      loop
      onDismiss={(payload) => console.log('closed at', payload.index)}
    >
      {images.map((image, index) => (
        <Gallery.Image index={index} key={image.url} style={styles.thumbnail}>
          <Image source={image.url} style={styles.image} />
        </Gallery.Image>
      ))}
    </Gallery>
  )
}
```

### Imperative

```tsx
import { Gallery } from 'react-native-jet-gallery'

// Plain fade in
Gallery.open({ images, initialIndex: 2, loop: true })

// Transition from a rect, in window coordinates (points)
Gallery.open({
  images,
  origin: { x: 40, y: 400, width: 100, height: 100, borderRadius: 12 },
})

Gallery.close()
Gallery.isVisible()
```

## API

### `<Gallery>`

Takes `images`, `children`, and every option below.

| Prop | Type | Default | Description |
| --- | --- | --- | --- |
| `images` | `GalleryImageSource[]` | | Images to show, see [types](#types) |
| `loop` | `boolean` | `false` | Wrap around past the first and last image |
| `rotation` | `boolean` | `true` | Rotate with the device, see [Rotation](#rotation) |
| `actions` | `GalleryAction[]` | | Toolbar buttons, see [types](#types) |
| `backgroundColor` | `string` | `#000000` | Viewer background |
| `indicatorColor` | `string` | white | Active page bullet |
| `indicatorInactiveColor` | `string` | translucent white | Inactive page bullets |
| `onShow` | `() => void` | | Viewer finished presenting |
| `onIndexChange` | `(payload) => void` | | Current page changed |
| `onActionPress` | `(actionId, payload) => void` | | Any action pressed, in addition to that action's own `onPress` |
| `onDismiss` | `(payload) => void` | | Viewer dismissed |

Every `payload` is `{ index, url }`.

### `<Gallery.Image>`

| Prop | Type | Description |
| --- | --- | --- |
| `index` | `number` | Index of this thumbnail in the surrounding gallery's `images` |
| `onLongPress` | `(payload) => void` | Long press on the thumbnail |
| `disabled` | `boolean` | Disables the pressable |
| `style` | `StyleProp<ViewStyle>` | Style for the wrapping pressable. A uniform numeric `borderRadius` is animated during the transition |

### `Gallery.open(options)`

Takes every `<Gallery>` prop except `children`, plus:

| Option | Type | Description |
| --- | --- | --- |
| `initialIndex` | `number` | Page to open at, default `0` |
| `origin` | `TransitionRect` | Rect to transition from and back to. Omit for a plain fade |

### `Gallery.close()`

Dismisses the viewer. Safe to call during the open transition; the dismiss runs as soon as presentation completes.

### `Gallery.isVisible()`

Whether a viewer is currently presented.

### Types

```ts
interface GalleryImageSource {
  /** http, https, or file URL. */
  url: string
  /** Smaller copy your thumbnail renders; reused for the transition and as the page placeholder. */
  thumbnail?: string
  /** Intrinsic pixel size; lets the transition land on the real aspect before the full image loads. */
  width?: number
  height?: number
}

interface GalleryAction {
  id: string
  /** SF Symbol name. */
  icon: string
  /** Accessibility label; falls back to id. */
  title?: string
  onPress?: (payload: GalleryEventPayload) => void
}

interface TransitionRect {
  /** Window coordinates, in points. */
  x: number
  y: number
  width: number
  height: number
  borderRadius?: number
}

interface GalleryEventPayload {
  index: number
  url: string
}
```

## Guides

### Rotation

The gallery rotates with the device by default; pass `rotation={false}` to keep the orientation it opened in. UIKit caps a presented controller at the orientations the app allows, so a portrait-locked app has to widen them while the gallery is open. With [expo-screen-orientation](https://docs.expo.dev/versions/latest/sdk/screen-orientation/), unlock on show and lock again on dismiss:

```tsx
<Gallery
  images={images}
  onShow={() => ScreenOrientation.unlockAsync()}
  onDismiss={() => ScreenOrientation.lockAsync(ScreenOrientation.OrientationLock.PORTRAIT_UP)}
>
```

### Nesting inside a pressable

`Gallery.Image` renders gesture-handler's `Pressable`, so it keeps working inside gesture-handler pressables and touchables. The innermost pressable wins:

```tsx
import { Pressable } from 'react-native-gesture-handler'

<Pressable onPress={openPost}>
  <Text>Tapping the image opens the gallery; tapping anywhere else presses the card.</Text>

  <Gallery.Image index={0}>
    <Image source={url} style={styles.image} />
  </Gallery.Image>
</Pressable>
```

### Images and caching

The library loads through SDWebImage's shared cache, the same one expo-image uses, so the two cooperate:

- Pass `thumbnail` with the URL your thumbnail view renders. When it is already decoded, the transition and the first page use it until the full image loads.
- Pass `width` and `height` so the transition lands on the image's real aspect ratio before it has loaded.
- expo-image only fills the shared memory cache with `cachePolicy="memory-disk"`. With its default `disk` policy, the gallery borrows the bitmap straight from the pressed view instead.
- Full-size downloads are written to the shared disk cache under the plain URL, so an image viewed in the gallery is a cache hit for expo-image afterwards.
- Pages decode at up to 1.5x screen pixels per axis, enough for zooming without holding full-resolution bitmaps, and the pages either side of the current one are prefetched.

## How the transition works

- **Open.** The thumbnail is measured in window coordinates and passed to native, which flies a copy of the image from that rect into an aspect-fit fullscreen frame. The copy uses the best bitmap already decoded: the full image if any SDWebImage client has it in memory, else the `thumbnail`, else the pixels the pressed view is rendering, else a snapshot of the view.
- **Seamless landing.** The first page is seeded with the same bitmap, so the copy lands on identical pixels and the full image simply replaces it once loaded.
- **GIFs.** The current frame is handed from the thumbnail to the flying copy to the page, and back on dismiss, so the animation keeps playing instead of restarting.
- **Live toolbar.** The open runs as a self-driven interactive transition, so the toolbar is tappable from the first frame; a close tapped mid-flight is honored as soon as presentation completes.
- **Dismiss.** While paging, JS keeps native updated with the on-screen frame of the current image's thumbnail, so an interactive dismiss lands on it. If that thumbnail is unmounted or offscreen, the dismiss falls back to a fade.

## Sponsors

<p align="center">
  <a href="https://acorn.blue"><img alt="Acorn" src="https://acorn.blue/images/acorn.png" width="80"></a>
</p>

<p align="center">
  Built for and sponsored by <a href="https://acorn.blue">Acorn</a>, a Reddit client for iOS.
</p>

## License

MIT

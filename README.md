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

- Wrap **your own image component** — expo-image, `Image`, anything — and get a fullscreen viewer with a shared-element-style open/dismiss transition
- **Imperative API** to open the gallery programmatically, with a transition when you pass an origin rect
- Horizontal **paging** with optional infinite **looping**
- **Pinch** and **double-tap zoom**, interactive **swipe-down to dismiss** that follows your finger and lands on the correct thumbnail — even after paging
- Animated **GIF/APNG/WebP** playback fullscreen (SDWebImage)
- **Custom actions** rendered as SF Symbol buttons in the toolbar, with per-action `onPress`
- Animated **dot page indicator** — the active bullet is a double-width pill that follows your finger as you scroll, with configurable colors
- iOS only for now; calls are safe no-ops on other platforms

> **Note:** Nitro Modules require a development build — this library does not work in Expo Go.

## Installation

```sh
npm install react-native-jet-gallery react-native-nitro-modules
cd ios && pod install
```

Using Expo? `npx expo prebuild` handles the pod install.

## Declarative API

```tsx
import { Image } from 'expo-image'
import { Gallery } from 'react-native-jet-gallery'

const urls = ['https://example.com/1.jpg', 'https://example.com/2.gif']

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
      loop
      onDismiss={(payload) => console.log('closed at', payload.index)}
      urls={urls}
    >
      {urls.map((url, index) => (
        <Gallery.Image index={index} key={url} style={styles.thumbnail}>
          <Image source={url} style={styles.image} />
        </Gallery.Image>
      ))}
    </Gallery>
  )
}
```

`Gallery.Image` wraps your thumbnail in a pressable, measures it on press, and opens the fullscreen viewer with a transition from that exact frame. Dismissing transitions back to the thumbnail of the image you are currently on, not just the one you opened from.

## Imperative API

```tsx
import { Gallery } from 'react-native-jet-gallery'

// Plain fade-in
Gallery.open({ urls, initialIndex: 2, loop: true })

// Transition from a rect (window coordinates, in points)
Gallery.open({
  urls: ['https://example.com/1.jpg'],
  origin: { x: 40, y: 400, width: 100, height: 100, borderRadius: 12 },
})

Gallery.close()
Gallery.isVisible()
```

## Options

| Option | Type | Description |
| --- | --- | --- |
| `urls` | `string[]` | Image URLs (http/https/file) |
| `initialIndex` | `number` | Page to open at (imperative only; `Gallery.Image` uses its `index`) |
| `loop` | `boolean` | Wrap around past the first/last image |
| `origin` | `TransitionRect` | Rect to transition from/back to (imperative only) |
| `actions` | `GalleryAction[]` | Toolbar buttons: `{ id, icon, title?, onPress? }` — `icon` is an SF Symbol name |
| `backgroundColor` | `string` | Viewer background, default `#000000` |
| `indicatorColor` | `string` | Active page bullet color, default white |
| `indicatorInactiveColor` | `string` | Inactive page bullet color, default translucent white |
| `onShow` | `() => void` | Viewer finished presenting |
| `onIndexChange` | `(payload) => void` | Current page changed; payload is `{ index, url }` |
| `onActionPress` | `(actionId, payload) => void` | Any action pressed (in addition to the action's own `onPress`) |
| `onDismiss` | `(payload) => void` | Viewer dismissed |

## How the transition works

The thumbnail is measured in window coordinates (`measureInWindow`) and passed to native, which animates a copy of the image from that rect into an aspect-fit fullscreen frame. If the image is already in the shared SDWebImage cache (expo-image uses the same cache on iOS), the transition renders actual pixels — including animating GIFs — otherwise it falls back to a snapshot of the thumbnail. While paging, the library keeps native updated with the on-screen frame of the current image's thumbnail so an interactive dismiss can land on it; if that thumbnail is unmounted or offscreen, the dismiss falls back to a fade.

## License

MIT

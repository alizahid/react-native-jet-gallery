import type { HybridObject } from 'react-native-nitro-modules'

export interface TransitionRect {
  /** Window x coordinate, in points. */
  x: number
  /** Window y coordinate, in points. */
  y: number
  width: number
  height: number
  borderRadius?: number
}

export interface GalleryEventPayload {
  index: number
  url: string
}

export interface GalleryActionPayload {
  actionId: string
  index: number
  url: string
}

export interface GalleryActionSpec {
  id: string
  title?: string
  /** SF Symbol name on iOS. */
  icon: string
}

export interface GalleryOpenOptions {
  urls: string[]
  initialIndex?: number
  loop?: boolean
  /** Present-from rect in window coordinates; omit for a plain fade/zoom. */
  origin?: TransitionRect
  /** React tag of the pressed thumbnail; enables snapshot transition + auto-hide. */
  sourceTag?: number
  actions?: GalleryActionSpec[]
  backgroundColor?: string
  /** Color of the active page bullet. */
  indicatorColor?: string
  /** Color of inactive page bullets. */
  indicatorInactiveColor?: string
  onShow?: () => void
  onIndexChange?: (payload: GalleryEventPayload) => void
  onAction?: (payload: GalleryActionPayload) => void
  onDismiss?: (payload: GalleryEventPayload) => void
}

export interface GalleryController extends HybridObject<{ ios: 'swift' }> {
  readonly isVisible: boolean
  open(options: GalleryOpenOptions): void
  close(): void
  /**
   * Keeps native updated with the on-screen frame of the thumbnail for `index`
   * so an interactive dismiss can animate back to it. Passing no rect clears
   * the target; native falls back to a fade-out dismiss for that index.
   */
  setDismissTarget(index: number, rect?: TransitionRect): void
}

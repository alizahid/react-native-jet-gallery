import type {
  GalleryEventPayload,
  GalleryImageSource,
  TransitionRect,
} from './specs/GalleryController.nitro'

export type { GalleryEventPayload, GalleryImageSource, TransitionRect }

export interface GalleryAction {
  id: string
  title?: string
  /** SF Symbol name on iOS. */
  icon: string
  onPress?: (payload: GalleryEventPayload) => void
}

export interface GalleryOptions {
  /** Wrap around when scrolling past the first or last image. */
  loop?: boolean
  actions?: GalleryAction[]
  backgroundColor?: string
  /** Color of the active page bullet. Defaults to white. */
  indicatorColor?: string
  /** Color of inactive page bullets. Defaults to translucent white. */
  indicatorInactiveColor?: string
  onShow?: () => void
  onIndexChange?: (payload: GalleryEventPayload) => void
  /** Fires for every action press, in addition to the action's own onPress. */
  onActionPress?: (actionId: string, payload: GalleryEventPayload) => void
  onDismiss?: (payload: GalleryEventPayload) => void
}

export interface GalleryOpenOptions extends GalleryOptions {
  images: GalleryImageSource[]
  initialIndex?: number
  /**
   * Frame to animate from, in window coordinates (points). When set, the
   * gallery zooms out of this rect and back into it on dismiss. Omit for a
   * plain fade presentation.
   */
  origin?: TransitionRect
  /** @internal React tag of the pressed thumbnail; set by Gallery.Image. */
  sourceTag?: number
}

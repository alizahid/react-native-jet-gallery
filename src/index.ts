import { GalleryImage, GalleryRoot } from './gallery'
import { close, isVisible, open } from './open'

export const Gallery = Object.assign(GalleryRoot, {
  Image: GalleryImage,
  close,
  isVisible,
  open,
})

export type { GalleryImageProps, GalleryProps } from './gallery'
export type {
  GalleryAction,
  GalleryEventPayload,
  GalleryImageSource,
  GalleryOpenOptions,
  GalleryOptions,
  TransitionRect,
} from './types'

import {
  createContext,
  type ReactNode,
  useCallback,
  useContext,
  useMemo,
  useRef,
  useSyncExternalStore,
} from 'react'
import {
  findNodeHandle,
  type StyleProp,
  StyleSheet,
  type View,
  type ViewStyle,
} from 'react-native'
// The core Pressable never receives the touch when it is nested inside a
// gesture-handler pressable; gesture-handler's own Pressable nests correctly,
// with the innermost one winning.
import { Pressable } from 'react-native-gesture-handler'
import { open, setDismissTarget } from './open'
import type { TransitionRect } from './specs/GalleryController.nitro'
import type {
  GalleryEventPayload,
  GalleryImageSource,
  GalleryOptions,
} from './types'

type RegistryEntry = {
  borderRadius?: number
  view: View
}

type GalleryContextValue = {
  isHidden: (index: number) => boolean
  openAt: (index: number) => void
  register: (index: number, view: View | null, borderRadius?: number) => void
  subscribe: (listener: () => void) => () => void
  urlAt: (index: number) => string
}

const GalleryContext = createContext<GalleryContextValue | null>(null)

export interface GalleryProps extends GalleryOptions {
  images: GalleryImageSource[]
  children: ReactNode
}

export function GalleryRoot({ images, children, ...options }: GalleryProps) {
  const registry = useRef(new Map<number, RegistryEntry>())

  // The hidden index lives outside React state so a page change re-renders
  // only the two thumbnails whose visibility flipped, not every Gallery.Image.
  const hiddenIndex = useRef<number | null>(null)
  const listeners = useRef(new Set<() => void>())

  const setHiddenIndex = useCallback((index: number | null) => {
    if (hiddenIndex.current === index) {
      return
    }

    hiddenIndex.current = index

    for (const listener of listeners.current) {
      listener()
    }
  }, [])

  const subscribe = useCallback((listener: () => void) => {
    listeners.current.add(listener)

    return () => {
      listeners.current.delete(listener)
    }
  }, [])

  const isHidden = useCallback(
    (index: number) => hiddenIndex.current === index,
    []
  )

  const imagesRef = useRef(images)
  imagesRef.current = images

  const optionsRef = useRef(options)
  optionsRef.current = options

  const register = useCallback(
    (index: number, view: View | null, borderRadius?: number) => {
      if (view) {
        registry.current.set(index, { borderRadius, view })
      } else {
        registry.current.delete(index)
      }
    },
    []
  )

  const openAt = useCallback(
    (index: number) => {
      // The pressed thumbnail is hidden natively (alpha) while presented, so JS
      // must not also set opacity — the two writes race and native can capture
      // the already-hidden alpha as the value to restore. JS opacity is only
      // used for paged-to siblings, which native never touches.
      const launch = (origin?: TransitionRect, sourceTag?: number) => {
        open({
          ...optionsRef.current,
          images: imagesRef.current,
          initialIndex: index,
          origin,
          sourceTag,
          onIndexChange: (payload) => {
            const sibling = registry.current.get(payload.index)

            if (sibling) {
              setHiddenIndex(payload.index)

              sibling.view.measureInWindow((x, y, width, height) => {
                setDismissTarget(payload.index, {
                  borderRadius: sibling.borderRadius,
                  height,
                  width,
                  x,
                  y,
                })
              })
            } else {
              setHiddenIndex(null)
              setDismissTarget(payload.index)
            }

            optionsRef.current.onIndexChange?.(payload)
          },
          onDismiss: (payload) => {
            setHiddenIndex(null)

            optionsRef.current.onDismiss?.(payload)
          },
        })
      }

      const entry = registry.current.get(index)

      if (entry && typeof entry.view.measureInWindow === 'function') {
        entry.view.measureInWindow((x, y, width, height) => {
          launch(
            { borderRadius: entry.borderRadius, height, width, x, y },
            findNodeHandle(entry.view) ?? undefined
          )
        })
      } else {
        launch()
      }
    },
    [setHiddenIndex]
  )

  const urlAt = useCallback(
    (index: number) => imagesRef.current[index]?.url ?? '',
    []
  )

  const value = useMemo(
    () => ({ isHidden, openAt, register, subscribe, urlAt }),
    [isHidden, openAt, register, subscribe, urlAt]
  )

  return (
    <GalleryContext.Provider value={value}>{children}</GalleryContext.Provider>
  )
}

export interface GalleryImageProps {
  index: number
  children: ReactNode
  disabled?: boolean
  onLongPress?: (payload: GalleryEventPayload) => void
  style?: StyleProp<ViewStyle>
}

export function GalleryImage({
  index,
  children,
  disabled,
  onLongPress,
  style,
}: GalleryImageProps) {
  const context = useContext(GalleryContext)

  if (!context) {
    throw new Error('Gallery.Image must be rendered inside a <Gallery>')
  }

  const { isHidden, openAt, register, subscribe, urlAt } = context

  const hidden = useSyncExternalStore(subscribe, () => isHidden(index))

  // Only a uniform numeric radius participates in the transition — per-corner
  // and percentage radii can't be tweened as a single layer.cornerRadius.
  const flattened = StyleSheet.flatten(style)
  const borderRadius =
    typeof flattened?.borderRadius === 'number'
      ? flattened.borderRadius
      : undefined

  const ref = useCallback(
    (view: View | null) => register(index, view, borderRadius),
    [borderRadius, index, register]
  )

  return (
    <Pressable
      collapsable={false}
      disabled={disabled}
      onLongPress={
        onLongPress
          ? () => onLongPress({ index, url: urlAt(index) })
          : undefined
      }
      onPress={() => openAt(index)}
      ref={ref}
      style={[style, hidden && styles.hidden]}
    >
      {children}
    </Pressable>
  )
}

const styles = {
  hidden: { opacity: 0 },
} as const

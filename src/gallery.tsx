import {
  createContext,
  type ReactNode,
  useCallback,
  useContext,
  useMemo,
  useRef,
  useState,
} from 'react'
import {
  findNodeHandle,
  Pressable,
  type StyleProp,
  type View,
  type ViewStyle,
} from 'react-native'
import { open, setDismissTarget } from './open'
import type { TransitionRect } from './specs/GalleryController.nitro'
import type { GalleryOptions } from './types'

type GalleryContextValue = {
  hiddenIndex: number | null
  openAt: (index: number) => void
  register: (index: number, view: View | null) => void
}

const GalleryContext = createContext<GalleryContextValue | null>(null)

export interface GalleryProps extends GalleryOptions {
  urls: string[]
  children: ReactNode
}

export function GalleryRoot({ urls, children, ...options }: GalleryProps) {
  const registry = useRef(new Map<number, View>())

  const [hiddenIndex, setHiddenIndex] = useState<number | null>(null)

  const urlsRef = useRef(urls)
  urlsRef.current = urls

  const optionsRef = useRef(options)
  optionsRef.current = options

  const register = useCallback((index: number, view: View | null) => {
    if (view) {
      registry.current.set(index, view)
    } else {
      registry.current.delete(index)
    }
  }, [])

  const openAt = useCallback((index: number) => {
    // The pressed thumbnail is hidden natively (alpha) while presented, so JS
    // must not also set opacity — the two writes race and native can capture
    // the already-hidden alpha as the value to restore. JS opacity is only
    // used for paged-to siblings, which native never touches.
    const launch = (origin?: TransitionRect, sourceTag?: number) => {
      open({
        ...optionsRef.current,
        initialIndex: index,
        origin,
        sourceTag,
        urls: urlsRef.current,
        onIndexChange: (payload) => {
          const sibling = registry.current.get(payload.index)

          if (sibling) {
            setHiddenIndex(payload.index)

            sibling.measureInWindow((x, y, width, height) => {
              setDismissTarget(payload.index, { x, y, width, height })
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

    const view = registry.current.get(index)

    if (view) {
      view.measureInWindow((x, y, width, height) => {
        launch({ x, y, width, height }, findNodeHandle(view) ?? undefined)
      })
    } else {
      launch()
    }
  }, [])

  const value = useMemo(
    () => ({ hiddenIndex, openAt, register }),
    [hiddenIndex, openAt, register]
  )

  return (
    <GalleryContext.Provider value={value}>{children}</GalleryContext.Provider>
  )
}

export interface GalleryImageProps {
  index: number
  children: ReactNode
  disabled?: boolean
  style?: StyleProp<ViewStyle>
}

export function GalleryImage({
  index,
  children,
  disabled,
  style,
}: GalleryImageProps) {
  const context = useContext(GalleryContext)

  if (!context) {
    throw new Error('Gallery.Image must be rendered inside a <Gallery>')
  }

  const { hiddenIndex, openAt, register } = context

  const ref = useCallback(
    (view: View | null) => register(index, view),
    [index, register]
  )

  return (
    <Pressable
      collapsable={false}
      disabled={disabled}
      onPress={() => openAt(index)}
      ref={ref}
      style={[style, hiddenIndex === index && styles.hidden]}
    >
      {children}
    </Pressable>
  )
}

const styles = {
  hidden: { opacity: 0 },
} as const

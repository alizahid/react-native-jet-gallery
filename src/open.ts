import { getController } from './controller'
import type { TransitionRect } from './specs/GalleryController.nitro'
import type { GalleryOpenOptions } from './types'

export function open(options: GalleryOpenOptions): void {
  const controller = getController()

  const initialIndex = options.initialIndex ?? 0

  if (!controller || options.images.length === 0) {
    options.onDismiss?.({
      index: initialIndex,
      url: options.images[initialIndex]?.url ?? '',
    })

    return
  }

  const { actions, onActionPress, onDismiss, ...rest } = options

  const handlers = new Map(
    actions?.map((action) => [action.id, action.onPress])
  )

  controller.open({
    ...rest,
    actions: actions?.map(({ id, title, icon }) => ({ id, title, icon })),
    onAction: ({ actionId, index, url }) => {
      const payload = { index, url }

      handlers.get(actionId)?.(payload)
      onActionPress?.(actionId, payload)
    },
    onDismiss: (payload) => {
      handlers.clear()
      onDismiss?.(payload)
    },
  })
}

export function close(): void {
  getController()?.close()
}

export function isVisible(): boolean {
  return getController()?.isVisible ?? false
}

/** @internal Used by Gallery.Image to keep the dismiss target in sync. */
export function setDismissTarget(index: number, rect?: TransitionRect): void {
  getController()?.setDismissTarget(index, rect)
}

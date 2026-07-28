import { Platform } from 'react-native'
import { NitroModules } from 'react-native-nitro-modules'
import type { GalleryController } from './specs/GalleryController.nitro'

let instance: GalleryController | null = null
let warned = false

export function getController(): GalleryController | null {
  if (Platform.OS !== 'ios') {
    if (__DEV__ && !warned) {
      warned = true
      console.warn(
        `react-native-nitro-gallery is not supported on ${Platform.OS} yet; calls are no-ops.`
      )
    }

    return null
  }

  instance ??=
    NitroModules.createHybridObject<GalleryController>('GalleryController')

  return instance
}

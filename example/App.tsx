import { Image } from 'expo-image'
import { StatusBar } from 'expo-status-bar'
import { PressableOpacity } from 'pressto'
import { type ComponentType, type ReactNode, useMemo } from 'react'
import {
  Alert,
  Pressable as CorePressable,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
  type ViewStyle,
} from 'react-native'
import {
  Gesture,
  GestureDetector,
  GestureHandlerRootView,
  Pressable as GesturePressable,
} from 'react-native-gesture-handler'
import { Gallery, type GalleryAction } from 'react-native-jet-gallery'

/**
 * Mimics Acorn's post card: a horizontal swipe-actions Pan wrapping a pressto
 * pressable wrapping the content.
 */
function AcornStack({ children, onPress, style }: ParentPressableProps) {
  const pan = useMemo(() => Gesture.Pan().activeOffsetX([-40, 40]), [])

  return (
    <GestureDetector gesture={pan}>
      <PressableOpacity onPress={onPress} style={style}>
        <View collapsable={false}>{children}</View>
      </PressableOpacity>
    </GestureDetector>
  )
}

type ParentPressableProps = {
  children?: ReactNode
  onPress?: () => void
  style?: ViewStyle
}

const parents: Array<{
  Component: ComponentType<ParentPressableProps>
  key: string
  label: string
}> = [
  {
    Component: CorePressable as ComponentType<ParentPressableProps>,
    key: 'core',
    label: 'react-native Pressable',
  },
  {
    Component: GesturePressable as ComponentType<ParentPressableProps>,
    key: 'gesture-handler',
    label: 'gesture-handler Pressable',
  },
  {
    Component: PressableOpacity as ComponentType<ParentPressableProps>,
    key: 'pressto',
    label: 'pressto PressableOpacity',
  },
  {
    Component: AcornStack,
    key: 'acorn',
    label: 'pan + pressto (Acorn stack)',
  },
]

const urls = [
  'https://picsum.photos/id/10/1200/800',
  'https://picsum.photos/id/1015/900/1600',
  'https://picsum.photos/id/1025/1200/1200',
  'https://upload.wikimedia.org/wikipedia/commons/2/2c/Rotating_earth_%28large%29.gif',
  'https://picsum.photos/id/1039/1600/900',
  'https://picsum.photos/id/1043/800/1200',
]

const actions: GalleryAction[] = [
  {
    icon: 'square.and.arrow.down',
    id: 'save',
    onPress: (payload) => {
      Alert.alert('Save', `${payload.index}: ${payload.url}`)
    },
    title: 'Save',
  },
  {
    icon: 'square.and.arrow.up',
    id: 'share',
    onPress: (payload) => {
      Alert.alert('Share', `${payload.index}: ${payload.url}`)
    },
    title: 'Share',
  },
]

export default function App() {
  return (
    <GestureHandlerRootView style={styles.main}>
      <StatusBar style="light" />

      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.title}>Jet Gallery</Text>

        <Gallery
          actions={actions}
          loop
          onDismiss={(payload) => {
            console.log('dismissed at', payload.index)
          }}
          onActionPress={(actionId, payload) => {
            console.log('action', actionId, 'at', payload.index)
          }}
          onIndexChange={(payload) => {
            console.log('index changed to', payload.index)
          }}
          onShow={() => {
            console.log('gallery shown')
          }}
          urls={urls}
        >
          <View style={styles.grid}>
            {urls.map((url, index) => (
              <Gallery.Image
                index={index}
                key={url}
                onLongPress={(payload) => {
                  Alert.alert('Long press', `${payload.index}: ${payload.url}`)
                }}
                style={styles.thumbnail}
              >
                <Image contentFit="cover" source={url} style={styles.image} />
              </Gallery.Image>
            ))}
          </View>
        </Gallery>

        {parents.map(({ Component, key, label }) => (
          <View key={key}>
            <Text style={styles.subtitle}>Inside a {label}</Text>

            <Gallery
              loop={false}
              onShow={() => {
                console.log(`${key} gallery shown`)
              }}
              urls={[urls[4] ?? '', urls[5] ?? '']}
            >
              <Component
                onPress={() => {
                  console.log(`${key} card pressed`)
                }}
                style={styles.card}
              >
                <Text style={styles.body}>
                  Tapping an image opens the gallery; tapping anywhere else
                  presses the card.
                </Text>

                <View style={styles.row}>
                  {[urls[4] ?? '', urls[5] ?? ''].map((url, index) => (
                    <Gallery.Image
                      index={index}
                      key={url}
                      onLongPress={(payload) => {
                        console.log(`${key} long press at ${payload.index}`)
                      }}
                      style={styles.cardImage}
                    >
                      <Image
                        contentFit="cover"
                        source={url}
                        style={styles.image}
                      />
                    </Gallery.Image>
                  ))}
                </View>
              </Component>
            </Gallery>
          </View>
        ))}

        <TouchableOpacity
          onPress={() => {
            Gallery.open({
              actions,
              indicatorColor: '#ffd60a',
              initialIndex: 1,
              loop: true,
              urls,
            })
          }}
          style={styles.button}
        >
          <Text style={styles.label}>Open programmatically</Text>
        </TouchableOpacity>

        <TouchableOpacity
          onPress={() => {
            Gallery.open({
              origin: {
                height: 100,
                width: 100,
                x: 40,
                y: 400,
              },
              urls: [urls[0] ?? ''],
            })
          }}
          style={styles.button}
        >
          <Text style={styles.label}>Open from a rect</Text>
        </TouchableOpacity>
      </ScrollView>
    </GestureHandlerRootView>
  )
}

const styles = StyleSheet.create({
  body: {
    color: '#94a3b8',
    fontSize: 14,
    lineHeight: 20,
    marginBottom: 12,
  },
  card: {
    backgroundColor: '#141414',
    borderCurve: 'continuous',
    borderRadius: 12,
    padding: 12,
  },
  cardImage: {
    aspectRatio: 1,
    borderCurve: 'continuous',
    borderRadius: 8,
    flex: 1,
    overflow: 'hidden',
  },
  row: {
    flexDirection: 'row',
    gap: 8,
  },
  subtitle: {
    color: '#ffffff',
    fontSize: 18,
    fontWeight: '600',
    marginBottom: 12,
    marginTop: 24,
  },
  button: {
    alignItems: 'center',
    backgroundColor: '#1e1e1e',
    borderCurve: 'continuous',
    borderRadius: 12,
    marginTop: 16,
    padding: 16,
  },
  content: {
    padding: 20,
    paddingTop: 80,
  },
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 4,
  },
  image: {
    flex: 1,
  },
  label: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: '600',
  },
  main: {
    backgroundColor: '#000000',
    flex: 1,
  },
  thumbnail: {
    aspectRatio: 1,
    borderCurve: 'continuous',
    borderRadius: 8,
    overflow: 'hidden',
    width: '32%',
  },
  title: {
    color: '#ffffff',
    fontSize: 32,
    fontWeight: '700',
    marginBottom: 24,
  },
})

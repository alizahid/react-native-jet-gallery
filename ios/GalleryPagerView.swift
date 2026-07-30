import UIKit

protocol GalleryPagerViewDelegate: AnyObject {
  func pager(_ pager: GalleryPagerView, didChangeIndex index: Int)
  /** Continuous fractional page position in logical space; wraps when looping. */
  func pager(_ pager: GalleryPagerView, didScrollToProgress progress: CGFloat)
  func pager(_ pager: GalleryPagerView, didLoadImageAt index: Int)
  func pagerDidSingleTap(_ pager: GalleryPagerView)
}

final class GalleryPagerView: UIView {
  static let pageGap: CGFloat = 24

  weak var delegate: GalleryPagerViewDelegate?

  private let urls: [String]
  private let loop: Bool

  /// Physical item count multiplier for looping; recentered on idle so it is never exhausted.
  private let loopMultiplier = 400

  private let layout = UICollectionViewFlowLayout()
  private var collectionView: UICollectionView!

  private(set) var currentIndex: Int
  private var currentItem = 0
  private var pendingInitialIndex: Int?

  private var isLooping: Bool {
    return loop && urls.count > 1
  }

  private var itemCount: Int {
    return isLooping ? urls.count * loopMultiplier : urls.count
  }

  private var middleBase: Int {
    return isLooping ? urls.count * (loopMultiplier / 2) : 0
  }

  var panGestureRecognizer: UIPanGestureRecognizer {
    return collectionView.panGestureRecognizer
  }

  init(urls: [String], loop: Bool, initialIndex: Int) {
    self.urls = urls
    self.loop = loop
    self.currentIndex = initialIndex
    self.pendingInitialIndex = initialIndex

    super.init(frame: .zero)

    layout.scrollDirection = .horizontal
    layout.minimumLineSpacing = 0
    layout.minimumInteritemSpacing = 0

    collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    collectionView.isPagingEnabled = true
    collectionView.showsHorizontalScrollIndicator = false
    collectionView.contentInsetAdjustmentBehavior = .never
    collectionView.backgroundColor = .clear
    collectionView.dataSource = self
    collectionView.delegate = self
    collectionView.register(
      GalleryPageCell.self,
      forCellWithReuseIdentifier: GalleryPageCell.reuseIdentifier
    )
    addSubview(collectionView)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    let gap = Self.pageGap
    let frame = CGRect(x: -gap / 2, y: 0, width: bounds.width + gap, height: bounds.height)

    guard collectionView.frame != frame else {
      return
    }

    collectionView.frame = frame
    layout.itemSize = frame.size
    layout.invalidateLayout()

    if let initial = pendingInitialIndex {
      pendingInitialIndex = nil

      collectionView.reloadData()
      collectionView.layoutIfNeeded()

      let item = middleBase + initial
      currentItem = item
      scroll(to: item, animated: false)
    } else {
      // Keep the current page aligned when the page width changes (rotation).
      collectionView.layoutIfNeeded()
      scroll(to: currentItem, animated: false)
    }
  }

  var currentCell: GalleryPageCell? {
    return collectionView.cellForItem(at: IndexPath(item: currentItem, section: 0))
      as? GalleryPageCell
  }

  private func logicalIndex(for item: Int) -> Int {
    guard !urls.isEmpty else {
      return 0
    }

    return item % urls.count
  }

  private func scroll(to item: Int, animated: Bool) {
    let offset = CGPoint(x: CGFloat(item) * collectionView.frame.width, y: 0)
    collectionView.setContentOffset(offset, animated: animated)
  }

  /// Silently jump back into the middle band so the loop never hits an edge.
  private func recenterIfNeeded() {
    guard isLooping else {
      return
    }

    let threshold = urls.count * 2

    guard currentItem < threshold || currentItem > itemCount - threshold else {
      return
    }

    let item = middleBase + logicalIndex(for: currentItem)
    currentItem = item
    scroll(to: item, animated: false)
  }
}

extension GalleryPagerView: UICollectionViewDataSource {
  func collectionView(
    _ collectionView: UICollectionView,
    numberOfItemsInSection section: Int
  ) -> Int {
    return itemCount
  }

  func collectionView(
    _ collectionView: UICollectionView,
    cellForItemAt indexPath: IndexPath
  ) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(
      withReuseIdentifier: GalleryPageCell.reuseIdentifier,
      for: indexPath
    )

    if let cell = cell as? GalleryPageCell {
      cell.configure(url: urls[logicalIndex(for: indexPath.item)])

      cell.onSingleTap = { [weak self] in
        guard let self else {
          return
        }

        self.delegate?.pagerDidSingleTap(self)
      }

      let logical = logicalIndex(for: indexPath.item)

      cell.onImageLoad = { [weak self] in
        guard let self else {
          return
        }

        self.delegate?.pager(self, didLoadImageAt: logical)
      }
    }

    return cell
  }
}

extension GalleryPagerView: UICollectionViewDelegate {
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let width = scrollView.frame.width

    guard width > 0, pendingInitialIndex == nil else {
      return
    }

    let raw = scrollView.contentOffset.x / width
    let progress = isLooping ? raw : max(0, min(raw, CGFloat(itemCount - 1)))

    delegate?.pager(self, didScrollToProgress: progress)

    let item = max(0, min(Int(round(scrollView.contentOffset.x / width)), itemCount - 1))

    guard item != currentItem else {
      return
    }

    currentItem = item

    let logical = logicalIndex(for: item)

    if logical != currentIndex {
      currentIndex = logical
      delegate?.pager(self, didChangeIndex: logical)
    }
  }

  func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    recenterIfNeeded()
  }

  func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
    recenterIfNeeded()
  }
}

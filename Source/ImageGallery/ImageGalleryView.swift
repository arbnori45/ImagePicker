import UIKit
import Photos

protocol ImageGalleryPanGestureDelegate {

  func panGestureDidStart()
  func panGestureDidChange(translation: CGPoint, location: CGPoint, velocity: CGPoint)
  func panGestureDidEnd(translation: CGPoint, location: CGPoint, velocity: CGPoint)
  func imageSelected(array: NSMutableArray)
}

class ImageGalleryView: UIView {

  struct Dimensions {
    static let galleryHeight: CGFloat = 160
    static let galleryBarHeight: CGFloat = 34
    static let indicatorWidth: CGFloat = 41
    static let indicatorHeight: CGFloat = 8
  }

  lazy var collectionView: UICollectionView = { [unowned self] in
    let collectionView = UICollectionView(frame: CGRectMake(0, 0, 0, 0),
      collectionViewLayout: self.collectionViewLayout)
    collectionView.setTranslatesAutoresizingMaskIntoConstraints(false)
    collectionView.backgroundColor = self.configuration.mainColor
    collectionView.showsHorizontalScrollIndicator = false

    return collectionView
    }()

  lazy var collectionViewLayout: UICollectionViewLayout = { [unowned self] in
    let layout = UICollectionViewFlowLayout()
    layout.scrollDirection = .Horizontal
    layout.minimumInteritemSpacing = self.configuration.cellSpacing
    layout.minimumLineSpacing = 2
    layout.sectionInset = UIEdgeInsetsMake(0, 0, 0, 0)

    return layout
    }()

  lazy var topSeparator: UIView = { [unowned self] in
    let view = UIView()
    view.setTranslatesAutoresizingMaskIntoConstraints(false)
    view.addGestureRecognizer(self.panGestureRecognizer)
    view.backgroundColor = self.configuration.backgroundColor

    return view
    }()

  lazy var indicator: UIView = {
    let view = UIView()
    view.backgroundColor = UIColor(red:0.36, green:0.39, blue:0.42, alpha:1)
    view.layer.cornerRadius = Dimensions.indicatorHeight / 2
    view.setTranslatesAutoresizingMaskIntoConstraints(false)
    
    return view
    }()

  lazy var panGestureRecognizer: UIPanGestureRecognizer = {
    let gesture = UIPanGestureRecognizer()
    gesture.addTarget(self, action: "handlePanGestureRecognizer:")

    return gesture
    }()

  lazy var images: NSMutableArray = {
    let images = NSMutableArray()
    return images
    }()

  lazy var configuration: PickerConfiguration = {
    let configuration = PickerConfiguration()
    return configuration
    }()

  lazy var noImagesLabel: UILabel = { [unowned self] in
    let label = UILabel()
    label.font = self.configuration.noImagesFont
    label.textColor = self.configuration.noImagesColor
    label.text = self.configuration.noImagesTitle
    label.alpha = 0
    label.sizeToFit()
    self.addSubview(label)
    
    return label
    }()

  var collectionSize: CGSize!
  var delegate: ImageGalleryPanGestureDelegate?
  var selectedImages: NSMutableArray!
  var shouldTransform = false
  var imagesBeforeLoading = 0
  var isFetching = false

  // MARK: - Initializers

  override init(frame: CGRect) {
    super.init(frame: frame)

    selectedImages = NSMutableArray()
    collectionView.registerClass(ImageGalleryViewCell.self,
      forCellWithReuseIdentifier: CollectionView.reusableIdentifier)

    [collectionView, topSeparator].map { self.addSubview($0) }
    topSeparator.addSubview(indicator)
    backgroundColor = self.configuration.mainColor

    imagesBeforeLoading = 0
    fetchPhotos(0)
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Layout

  func updateFrames() {
    collectionView.dataSource = self
    collectionView.delegate = self

    topSeparator.frame = CGRectMake(0, 0, UIScreen.mainScreen().bounds.width, Dimensions.galleryBarHeight)
    indicator.frame = CGRectMake(UIScreen.mainScreen().bounds.width / 2 - Dimensions.indicatorWidth / 2, topSeparator.frame.height / 2 - Dimensions.indicatorHeight / 2, Dimensions.indicatorWidth, Dimensions.indicatorHeight)
    indicator.frame.size = CGSizeMake(Dimensions.indicatorWidth, Dimensions.indicatorHeight)
    collectionView.frame = CGRectMake(0, topSeparator.frame.height, UIScreen.mainScreen().bounds.width, frame.height - topSeparator.frame.height)
    collectionSize = CGSizeMake(frame.height - topSeparator.frame.height, frame.height - topSeparator.frame.height)
    noImagesLabel.center = collectionView.center
  }

  // MARK: - Photos handler

  func fetchPhotos(index: Int) {
    let imageManager = PHImageManager.defaultManager()

    let requestOptions = PHImageRequestOptions()
    requestOptions.synchronous = true

    let fetchOptions = PHFetchOptions()
    fetchOptions.sortDescriptors = [NSSortDescriptor(key:"creationDate", ascending: true)]

    let size = CGSizeMake(100, 150)

    if let fetchResult = PHAsset.fetchAssetsWithMediaType(PHAssetMediaType.Image, options: fetchOptions) {
      if fetchResult.count != 0 {
        imageManager.requestImageForAsset(fetchResult.objectAtIndex(fetchResult.count - 1 - index) as! PHAsset, targetSize: size, contentMode: PHImageContentMode.AspectFill, options: requestOptions, resultHandler: { (image, _) in
          self.images.addObject(image)
          if index > self.imagesBeforeLoading + 10 {
            println("1. Reloading")
            self.collectionView.reloadSections(NSIndexSet(index: 0))
            self.isFetching = false
          } else if index < fetchResult.count - 1 {
            println("Fetching")
            self.fetchPhotos(index+1)
          } else {
            println("2. Reloading")
            self.collectionView.reloadData()
            self.isFetching = false
          }
        })
      }
    }
  }

  // MARK: - Pan gesture recognizer

  func handlePanGestureRecognizer(gesture: UIPanGestureRecognizer) {
    let translation = gesture.translationInView(superview!)
    let location = gesture.locationInView(superview!)
    let velocity = gesture.velocityInView(superview!)

    if gesture.state == UIGestureRecognizerState.Began {
      delegate?.panGestureDidStart()
    } else if gesture.state == UIGestureRecognizerState.Changed {
      delegate?.panGestureDidChange(translation, location: location, velocity: velocity)
    } else if gesture.state == UIGestureRecognizerState.Ended {
      delegate?.panGestureDidEnd(translation, location: location, velocity: velocity)
    }
  }

  // MARK: - Private helpers

  func getImage(name: String) -> UIImage {
    let bundlePath = NSBundle(forClass: self.classForCoder).resourcePath?.stringByAppendingString("/ImagePicker.bundle")
    let bundle = NSBundle(path: bundlePath!)
    let traitCollection = UITraitCollection(displayScale: 3)
    let image = UIImage(named: name, inBundle: bundle, compatibleWithTraitCollection: traitCollection)

    return image!
  }

  func displayNoImagesMessage(hideCollectionView: Bool) {
    collectionView.alpha = hideCollectionView ? 0 : 1
    noImagesLabel.alpha = hideCollectionView ? 1 : 0
  }
}

// MARK: CollectionViewFlowLayout delegate methods

extension ImageGalleryView: UICollectionViewDelegateFlowLayout {

  func collectionView(collectionView: UICollectionView,
    layout collectionViewLayout: UICollectionViewLayout,
    sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
      return collectionSize
  }
}

// MARK: CollectionView delegate methods

extension ImageGalleryView: UICollectionViewDelegate {

  func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
    let cell = collectionView.cellForItemAtIndexPath(indexPath) as! ImageGalleryViewCell
    let image = images[indexPath.row] as! UIImage

    if cell.selectedImageView.image != nil {
      UIView.animateWithDuration(0.2, animations: { [unowned self] in
        cell.selectedImageView.transform = CGAffineTransformMakeScale(0, 0)
        }, completion: { _ in
          cell.selectedImageView.image = nil
      })
      selectedImages.removeObject(image)
    } else {
      cell.selectedImageView.image = getImage("selectedImageGallery")
      cell.selectedImageView.transform = CGAffineTransformMakeScale(0, 0)
      UIView.animateWithDuration(0.2, animations: { _ in
        cell.selectedImageView.transform = CGAffineTransformIdentity
        })
      selectedImages.insertObject(image, atIndex: 0)
    }

    delegate?.imageSelected(selectedImages)
  }

  func collectionView(collectionView: UICollectionView, willDisplayCell cell: UICollectionViewCell, forItemAtIndexPath indexPath: NSIndexPath) {
    if indexPath.row + 6 >= images.count && !isFetching {
      imagesBeforeLoading = images.count
      fetchPhotos(images.count)
      isFetching = true
    }
  }
}

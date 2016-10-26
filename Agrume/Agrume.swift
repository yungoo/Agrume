//
//  Agrume.swift
//  Agrume
//

import UIKit
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l > r
    default:
        return rhs < lhs
    }
}


open class Agrume: UIViewController {
    
    fileprivate static let TransitionAnimationDuration: TimeInterval = 0.3
    fileprivate static let MaxScalingForExpandingOffscreen: CGFloat = 1.25
    fileprivate static let MinScalingForExpandingOffscreen: CGFloat = 0.3
    
    fileprivate static let ReuseIdentifier = "ReuseIdentifier"
    
    fileprivate var images: [UIImage]!
    fileprivate var imageURLs: [URL]!
    fileprivate var startIndex: Int?
    fileprivate var currentIndex: Int = 0
    fileprivate var backgroundBlurStyle: UIBlurEffectStyle!
    
    public typealias DownloadCompletion = (_ image: UIImage?) -> Void
    
    open var didDismiss: (() -> Void)?
    open var didScroll: ((_ index: Int) -> Void)?
    open var download: ((_ url: URL, _ completion: DownloadCompletion) -> Void)?
    
    public convenience init(image: UIImage, backgroundBlurStyle: UIBlurEffectStyle? = .dark) {
        self.init(image: image, imageURL: nil, backgroundBlurStyle: backgroundBlurStyle)
    }
    
    public convenience init(imageURL: URL, backgroundBlurStyle: UIBlurEffectStyle? = .dark) {
        self.init(image: nil, imageURL: imageURL, backgroundBlurStyle: backgroundBlurStyle)
    }
    
    public convenience init(images: [UIImage], startIndex: Int? = nil, backgroundBlurStyle: UIBlurEffectStyle? = .dark) {
        self.init(image: nil, images: images, startIndex: startIndex, backgroundBlurStyle: backgroundBlurStyle)
    }
    
    public convenience init(imageURLs: [URL], startIndex: Int? = nil, backgroundBlurStyle: UIBlurEffectStyle? = .dark) {
        self.init(image: nil, imageURLs: imageURLs, startIndex: startIndex, backgroundBlurStyle: backgroundBlurStyle)
    }
    
    fileprivate init(image: UIImage? = nil, imageURL: URL? = nil, images: [UIImage]? = nil, imageURLs: [URL]? = nil,
                     startIndex: Int? = nil, backgroundBlurStyle: UIBlurEffectStyle? = .dark) {
        self.images = images
        if let image = image {
            self.images = [image]
        }
        self.imageURLs = imageURLs
        if let imageURL = imageURL {
            self.imageURLs = [imageURL]
        }
        
        self.startIndex = startIndex
        self.backgroundBlurStyle = backgroundBlurStyle!
        super.init(nibName: nil, bundle: nil)
        
        //        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("orientationDidChange"),
        //                name: UIDeviceOrientationDidChangeNotification, object: nil)
    }
    
    deinit {
        downloadTask?.cancel()
        //        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    fileprivate var backgroundSnapshot: UIImage!
    fileprivate var backgroundImageView: UIImageView!
    fileprivate lazy var blurView: UIVisualEffectView? = {
        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: self.backgroundBlurStyle))
        blurView.frame = self.view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return blurView
    }()
    fileprivate lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        layout.scrollDirection = .horizontal
        layout.itemSize = self.view.bounds.size
        
        let collectionView = UICollectionView(frame: self.view.bounds, collectionViewLayout: layout)
        collectionView.register(AgrumeCell.self, forCellWithReuseIdentifier: Agrume.ReuseIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isPagingEnabled = true
        collectionView.backgroundColor = UIColor.clear
        collectionView.delaysContentTouches = false
        collectionView.showsHorizontalScrollIndicator = false
        return collectionView
    }()
    fileprivate lazy var spinner: UIActivityIndicatorView = {
        let activityIndicatorStyle: UIActivityIndicatorViewStyle = self.backgroundBlurStyle == .dark ? .whiteLarge : .gray
        let spinner = UIActivityIndicatorView(activityIndicatorStyle: activityIndicatorStyle)
        spinner.center = self.view.center
        spinner.startAnimating()
        spinner.alpha = 0
        return spinner
    }()
    fileprivate var downloadTask: URLSessionDataTask?
    
    fileprivate lazy var indicator: UILabel = {
        let labelView = UILabel()
        labelView.lineBreakMode = NSLineBreakMode.byTruncatingTail
        labelView.numberOfLines = 1
        labelView.textAlignment = NSTextAlignment.left
        labelView.textColor = UIColor(red: 235.0/255.05, green: 235.0/255.05, blue: 235.0/255.05, alpha: 235.0/255.05)
        labelView.font = UIFont.systemFont(ofSize: 17)
        labelView.frame = CGRect(x: 20, y: self.view.bounds.height - 50, width: 100, height: 38)
        return labelView
    }()
    
    fileprivate lazy var downloadView: UIButton = {
        let btn = UIButton(type: UIButtonType.custom)
        btn.setTitle("保存", for: UIControlState())
        btn.setTitleColor(UIColor.gray, for: UIControlState.highlighted)
        btn.frame = CGRect(x: (self.view.bounds.width - 80) / 2,
                           y: self.view.bounds.height - 50, width: 80, height: 38)
        btn.addTarget(self, action: #selector(Agrume.saveToAlbum), for: UIControlEvents.touchUpInside)
        return btn
    }()
    
    func saveToAlbum() {
        if let cell = collectionView.cellForItem(at: IndexPath(row: currentIndex, section: 0)) as? AgrumeCell {
            if let image = cell.image {
                UIImageWriteToSavedPhotosAlbum(image, self, #selector(Agrume.image(_:didFinishSavingWithError:contextInfo:)), nil)
            }
        }
    }
    
    func image(_ image: UIImage, didFinishSavingWithError: NSError?, contextInfo: AnyObject) {
        if didFinishSavingWithError != nil {
            let alertView  = UIAlertController(title: nil, message: "保存失败", preferredStyle: UIAlertControllerStyle.alert)
            alertView.addAction(UIAlertAction(title: "知道了", style: UIAlertActionStyle.cancel, handler: nil))
            self.present(alertView, animated: true, completion: nil)
            return
        }
        let alertView  = UIAlertController(title: nil, message: "已保存", preferredStyle: UIAlertControllerStyle.alert)
        alertView.addAction(UIAlertAction(title: "知道了", style: UIAlertActionStyle.cancel, handler: nil))
        self.present(alertView, animated: true, completion: nil)
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        backgroundImageView = UIImageView(frame: view.bounds)
        backgroundImageView.image = backgroundSnapshot
        view.addSubview(backgroundImageView)
        if blurView != nil {
            view.addSubview(blurView!)
        }
        view.addSubview(collectionView)
        
        if let index = startIndex {
            currentIndex = index
            collectionView.scrollToItem(at: IndexPath(row: index, section: 0), at: [],
                                        animated: false)
        }
        updateIndicator()
        
        view.addSubview(spinner)
        view.addSubview(indicator)
        view.addSubview(downloadView)
    }
    
    fileprivate func updateIndicator() {
        indicator.text = "\(currentIndex + 1)/\(self.imageURLs.count)"
    }
    
    fileprivate var lastUsedOrientation: UIInterfaceOrientation!
    
    open override func viewWillAppear(_ animated: Bool) {
        lastUsedOrientation = UIApplication.shared.statusBarOrientation
    }
    
    fileprivate var initialOrientation: UIInterfaceOrientation!
    
    open func showFrom(_ viewController: UIViewController) {
        backgroundSnapshot = UIApplication.shared.delegate?.window??.rootViewController?.view.snapshot()
        
        view.isUserInteractionEnabled = false
        initialOrientation = UIApplication.shared.statusBarOrientation
        
        viewController.present(self, animated: false) {
            self.collectionView.alpha = 0
            self.collectionView.frame = self.view.bounds
            let scaling: CGFloat = Agrume.MinScalingForExpandingOffscreen
            self.collectionView.transform = CGAffineTransform(scaleX: scaling, y: scaling)
            
            DispatchQueue.main.async {
                UIView.animate(withDuration: Agrume.TransitionAnimationDuration,
                               delay: 0,
                               options: .beginFromCurrentState,
                               animations: {
                                [weak self] in
                                self?.collectionView.alpha = 1
                                self?.collectionView.transform = CGAffineTransform.identity
                    },
                               completion: {
                                [weak self] finished in
                                self?.view.isUserInteractionEnabled = finished
                    }
                )
            }
        }
    }
    
}

extension Agrume {
    
    // MARK: Rotation
    
    func orientationDidChange() {
        let orientation = UIDevice.current.orientation
        let landscapeToLandscape = UIDeviceOrientationIsLandscape(orientation) && UIInterfaceOrientationIsLandscape(lastUsedOrientation)
        let portraitToPortrait = UIDeviceOrientationIsPortrait(orientation) && UIInterfaceOrientationIsLandscape(lastUsedOrientation)
        if landscapeToLandscape || portraitToPortrait {
            let newOrientation = UIInterfaceOrientation(rawValue: orientation.rawValue)
            if newOrientation == lastUsedOrientation {
                return
            }
            lastUsedOrientation = newOrientation!
            UIView.animate(withDuration: 0.6, animations: {
                [weak self] in
                self?.updateLayoutsForCurrentOrientation()
                })
        }
    }
    
    open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: {
            [weak self] _ in
            self?.updateLayoutsForCurrentOrientation()
        }) {
            [weak self] _ in
            self?.lastUsedOrientation = UIApplication.shared.statusBarOrientation
        }
    }
    
    func updateLayoutsForCurrentOrientation() {
        var transform = CGAffineTransform.identity
        if initialOrientation == .portrait {
            switch (UIApplication.shared.statusBarOrientation) {
            case .landscapeLeft:
                transform = CGAffineTransform(rotationAngle: CGFloat(M_PI_2))
            case .landscapeRight:
                transform = CGAffineTransform(rotationAngle: CGFloat(-M_PI_2))
            case .portraitUpsideDown:
                transform = CGAffineTransform(rotationAngle: CGFloat(M_PI))
            default:
                break
            }
        } else if initialOrientation == .portraitUpsideDown {
            switch (UIApplication.shared.statusBarOrientation) {
            case .landscapeLeft:
                transform = CGAffineTransform(rotationAngle: CGFloat(-M_PI_2))
            case .landscapeRight:
                transform = CGAffineTransform(rotationAngle: CGFloat(M_PI_2))
            case .portrait:
                transform = CGAffineTransform(rotationAngle: CGFloat(M_PI))
            default:
                break
            }
        } else if initialOrientation == .landscapeLeft {
            switch (UIApplication.shared.statusBarOrientation) {
            case .landscapeRight:
                transform = CGAffineTransform(rotationAngle: CGFloat(M_PI))
            case .portrait:
                transform = CGAffineTransform(rotationAngle: CGFloat(-M_PI_2))
            case .portraitUpsideDown:
                transform = CGAffineTransform(rotationAngle: CGFloat(M_PI_2))
            default:
                break
            }
        } else if initialOrientation == .landscapeRight {
            switch (UIApplication.shared.statusBarOrientation) {
            case .landscapeLeft:
                transform = CGAffineTransform(rotationAngle: CGFloat(M_PI))
            case .portrait:
                transform = CGAffineTransform(rotationAngle: CGFloat(M_PI_2))
            case .portraitUpsideDown:
                transform = CGAffineTransform(rotationAngle: CGFloat(-M_PI_2))
            default:
                break
            }
        }
        
        backgroundImageView.center = view.center
        backgroundImageView.transform = transform.concatenating(CGAffineTransform(scaleX: 1, y: 1))
        
        spinner.center = view.center
        collectionView.frame = view.bounds
        
        let layout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        layout.itemSize = view.bounds.size
        layout.invalidateLayout()
        // Apply update two runloops into the future
        DispatchQueue.main.async {
            DispatchQueue.main.async {
                [unowned self] in
                for visibleCell in self.collectionView.visibleCells as! [AgrumeCell] {
                    visibleCell.updateScrollViewAndImageViewForCurrentMetrics()
                }
            }
        }
    }
    
}

extension Agrume: UICollectionViewDataSource {
    
    // MARK: UICollectionViewDataSource
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images?.count > 0 ? images.count : imageURLs.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        downloadTask?.cancel()
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Agrume.ReuseIdentifier, for: indexPath) as! AgrumeCell
        
        if let images = self.images {
            cell.image = images[(indexPath as NSIndexPath).row]
        } else if let imageURLs = self.imageURLs {
            spinner.alpha = 1
            let completion: DownloadCompletion = {
                [weak self] image in
                cell.image = image
                self?.spinner.alpha = 0
            }
            
            if let download = download {
                download(imageURLs[(indexPath as NSIndexPath).row], completion)
            } else {
                downloadImage(imageURLs[(indexPath as NSIndexPath).row], completion: completion)
            }
        }
        // Only allow panning if horizontal swiping fails. Horizontal swiping is only active for zoomed in images
        collectionView.panGestureRecognizer.require(toFail: cell.swipeGesture)
        cell.dismissAfterFlick = dismissAfterFlick()
        cell.dismissByExpanding = dismissByExpanding()
        return cell
    }
    
    func downloadImage(_ url: URL, completion: @escaping DownloadCompletion) {
        downloadTask = ImageDownloader.downloadImage(url) {
            image in
            completion(image)
        }
    }
    
    func dismissAfterFlick() -> (() -> Void) {
        return {
            [weak self] in
            UIView.animate(withDuration: Agrume.TransitionAnimationDuration,
                           delay: 0,
                           options: .beginFromCurrentState,
                           animations: {
                            if let strongSelf = self {
                                strongSelf.collectionView.alpha = 0
                                strongSelf.blurView?.alpha = 0
                            }
                },
                           completion: {_ in
                            if let strongSelf = self {
                                strongSelf.presentingViewController?.dismiss(animated: false) {
                                    strongSelf.didDismiss?()
                                }
                            }
                }
            )
        }
    }
    
    func dismissByExpanding() -> (() -> Void) {
        return {[weak self] in
            if let strongSelf = self {
                strongSelf.view.isUserInteractionEnabled = false
                
                UIView.animate(withDuration: Agrume.TransitionAnimationDuration,
                               delay: 0,
                               options: .beginFromCurrentState,
                               animations: {
                                if let strongSelf = self {
                                    strongSelf.collectionView.alpha = 0
                                    strongSelf.blurView?.removeFromSuperview()
                                    let scaling = Agrume.MaxScalingForExpandingOffscreen
                                    strongSelf.collectionView.transform = CGAffineTransform(scaleX: scaling, y: scaling)
                                }
                    },
                               completion: {_ in
                                if let strongSelf = self {
                                    strongSelf.presentingViewController?.dismiss(animated: false) {
                                        strongSelf.didDismiss?()
                                    }
                                }
                })
            }
        }
    }
    
}

extension Agrume: UICollectionViewDelegate {
    
    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        currentIndex = (indexPath as NSIndexPath).row
        updateIndicator()
        didScroll?((indexPath as NSIndexPath).row)
    }
    
}

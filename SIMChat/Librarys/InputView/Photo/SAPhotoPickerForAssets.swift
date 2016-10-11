//
//  SAPhotoPickerForAssets.swift
//  SIMChat
//
//  Created by sagesse on 9/21/16.
//  Copyright © 2016 sagesse. All rights reserved.
//

import UIKit
import Photos

internal class SAPhotoPickerForAssets: UICollectionViewController, UIGestureRecognizerDelegate {
    
    var scrollsToBottomOfLoad: Bool = false
    
    var allowsMultipleSelection: Bool = true
    
    weak var picker: SAPhotoPickerForImp?
    weak var selection: SAPhotoSelectionable?
    
    
    override var toolbarItems: [UIBarButtonItem]? {
        set { }
        get {
            if let toolbarItems = _toolbarItems {
                return toolbarItems
            }
            let toolbarItems = picker?.makeToolbarItems(for: .list)
            _toolbarItems = toolbarItems
            return toolbarItems
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItems = navigationController?.navigationItem.rightBarButtonItems
        
        collectionView?.backgroundColor = .white
        collectionView?.allowsSelection = false
        collectionView?.allowsMultipleSelection = false
        collectionView?.alwaysBounceVertical = true
        collectionView?.register(SAPhotoPickerForAssetsCell.self, forCellWithReuseIdentifier: "Item")
        
        // 添加手势
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panHandler(_:)))
        pan.delegate = self
        //pan.isEnabled = picker?.allowsMultipleSelection ?? false
        collectionView?.panGestureRecognizer.require(toFail: pan)
        collectionView?.addGestureRecognizer(pan)
        
        _reloadPhotos()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        
        let isHidden = _photos.isEmpty || toolbarItems?.isEmpty ?? true
        navigationController?.isToolbarHidden = isHidden
    }
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        _statusView?.frame = view.convert(CGRect(origin: .zero, size: view.bounds.size), from: view.window)
    }
    
    /// 手势将要开始的时候检查一下是否允许使用
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else {
            return true
        }
        let velocity = pan.velocity(in: collectionView)
        let point = pan.location(in: collectionView)
        // 检测手势的方向
        // 如果超出阀值视为放弃该手势
        if fabs(velocity.y) > 80 || fabs(velocity.y / velocity.x) > 2.5 {
            return false
        }
        guard let idx = _index(at: point), idx < (collectionView?.numberOfItems(inSection: 0) ?? 0) else {
            return false
        }
        _batchStartIndex = idx
        _batchIsSelectOperator = nil
        _batchOperatorItems.removeAll()
        return true
    }
    
    @objc private func panHandler(_ sender: UIPanGestureRecognizer) {
        guard let start = _batchStartIndex else {
            return
        }
        // step0: 计算选按下的位置所在的index, 这样子就会形成一个区域(start ~ end)
        let end = _index(at: sender.location(in: collectionView)) ?? 0
        let count = collectionView?.numberOfItems(inSection: 0) ?? 0
        
        // step1: 获取区域的第一个有效的元素为操作类型
        let operatorType = _batchIsSelectOperator ?? {
            let nidx = min(max(start, 0), count - 1)
            guard let cell = collectionView?.cellForItem(at: IndexPath(item: nidx, section: 0)) as? SAPhotoPickerForAssetsCell else {
                return false
            }
            _batchIsSelectOperator = !cell.photoIsSelected
            return !cell.photoIsSelected
        }()
        
        let sl = min(max(start, 0), count - 1)
        let nel = min(max(end, 0), count - 1)
        
        let ts = sl <= nel ? 1 : -1
        let tnsl = min(sl, nel)
        let tnel = max(sl, nel)
        let tosl = min(sl, _batchEndIndex ?? sl)
        let toel = max(sl, _batchEndIndex ?? sl)
        
        // step2: 对区域内的元素正向进行操作, 保存在_batchSelectedItems
        
        (tnsl ... tnel).enumerated().forEach {
            let idx = sl + $0.offset * ts
            guard !_batchOperatorItems.contains(idx) else {
                return // 己经添加
            }
            if _updateSelection(operatorType, at: idx) {
                _batchOperatorItems.insert(idx)
            }
        }
        // step3: 对区域外的元素进行反向操作, 针对在_batchSelectedItems
        (tosl ... toel).forEach { idx in
            if idx >= tnsl && idx <= tnel {
                return
            }
            guard _batchOperatorItems.contains(idx) else {
                return // 并没有添加
            }
            if _updateSelection(!operatorType, at: idx) {
                _batchOperatorItems.remove(idx)
            }
        }
        // step4: 更新结束点
        _batchEndIndex = nel
    }

    
    private func _index(at point: CGPoint) -> Int? {
        let x = point.x
        let y = point.y
        // 超出响应范围
        guard point.y > 10 && _itemSize.width > 0 && _itemSize.height > 0 else {
            return nil
        }
        let column = Int(x / (_itemSize.width + _minimumInteritemSpacing))
        let row = Int(y / (_itemSize.height + _minimumLineSpacing))
        // 超出响应范围
        guard row >= 0 else {
            return nil
        }
        
        return row * _columnCount + column
    }
    
    private func _cachePhotos(_ photos: [SAPhoto]) {
        // 缓存加速
//        let options = PHImageRequestOptions()
//        let scale = UIScreen.main.scale
//        let size = CGSize(width: 120 * scale, height: 120 * scale)
//        
//        options.deliveryMode = .fastFormat
//        options.resizeMode = .fast
//        
//        SAPhotoLibrary.shared.startCachingImages(for: photos, targetSize: size, contentMode: .aspectFill, options: options)
//        //SAPhotoLibrary.shared.stopCachingImages(for: photos, targetSize: size, contentMode: .aspectFill, options: options)
    }
    
    fileprivate func _updateStatus(_ newValue: SAPhotoStatus) {
        //_logger.trace(newValue)
        
        _status = newValue
        
        switch newValue {
        case .notError:
            
            _statusView?.removeFromSuperview()
            _statusView = nil
            collectionView?.isScrollEnabled = true
            
        case .notData:
            let error = _statusView ?? SAPhotoErrorView()
        
            error.title = "没有图片或视频"
            error.subtitle = "拍点照片和朋友们分享吧"
            error.frame = CGRect(origin: .zero, size: view.frame.size)
            
            _statusView = error
            
            view.addSubview(error)
            collectionView?.isScrollEnabled = false
            
        case .notPermission:
            let error = _statusView ?? SAPhotoErrorView()
            
            error.title = "没有权限"
            error.subtitle = "此应用程序没有权限访问您的照片\n在\"设置-隐私-图片\"中开启后即可查看"
            error.frame = CGRect(origin: .zero, size: view.frame.size)
            
            _statusView = error
            view.addSubview(error)
            collectionView?.isScrollEnabled = false
        }
        
        let isHidden = _photos.isEmpty || toolbarItems?.isEmpty ?? true
        navigationController?.isToolbarHidden = isHidden
    }
    
    fileprivate func _updateSelection(forSelected item: SAPhoto) {
        _logger.trace()
        
        collectionView?.visibleCells.forEach {
            let cell = $0 as? SAPhotoPickerForAssetsCell
            guard cell?.photo == item && !(cell?.photoIsSelected ?? false) else {
                return
            }
            cell?.updateSelection()
        }
    }
    fileprivate func _updateSelection(forDeselected item: SAPhoto?) {
        _logger.trace()
        
        collectionView?.visibleCells.forEach {
            let cell = $0 as? SAPhotoPickerForAssetsCell
            guard cell?.photoIsSelected ?? false else {
                return
            }
            cell?.updateSelection()
        }
    }
    
    fileprivate func _updateSelection(_ newValue: Bool, at index: Int) -> Bool {
        let photo = _photos[index]
        
        // step0: 查询选中的状态
        let selected = selection(self, indexOfSelectedItemsFor: photo) != NSNotFound
        // step1: 检查是否和newValue匹配, 如果匹配说明之前就是这个状态了, 更新失败
        guard selected != newValue else {
            return false
        }
        // step2: 更新状态, 如果被拒绝忽略该操作, 并且更新失败
        if newValue {
            guard selection?.selection(self, shouldSelectItemFor: photo) ?? true else {
                return false
            }
            selection?.selection(self, didSelectItemFor: photo)
        } else {
            guard selection?.selection(self, shouldDeselectItemFor: photo) ?? true else {
                return false
            }
            selection?.selection(self, didDeselectItemFor: photo)
        }
        // step4: 如果是正在显示的, 更新UI
        let idx = IndexPath(item: index, section: 0)
        if let cell = collectionView?.cellForItem(at: idx) as? SAPhotoPickerForAssetsCell {
            cell.photoIsSelected = newValue
        }
        // step5: 更新成功
        return true
    }
    
    fileprivate func _updateContentView(_ newResult: PHFetchResult<PHAsset>, _ inserts: [IndexPath], _ changes: [IndexPath], _ removes: [IndexPath]) {
        //_logger.trace("inserts: \(inserts), changes: \(changes), removes: \(removes)")
        
        // 更新数据
        _photos = _album?.photos(with: newResult) ?? []
        _photosResult = newResult
        
        // 更新视图
        if !(inserts.isEmpty && changes.isEmpty && removes.isEmpty) {
            collectionView?.performBatchUpdates({ [collectionView] in
                
                collectionView?.reloadItems(at: changes)
                collectionView?.deleteItems(at: removes)
                collectionView?.insertItems(at: inserts)
                
            }, completion: nil)
        }
        
        guard !_photos.isEmpty else {
            _updateStatus(.notData)
            return
        }
        
        _cachePhotos(_photos)
        _updateStatus(.notError)
        
        // update all
        _updateSelection(forDeselected: nil)
    }
    
    fileprivate func _reloadPhotos() {
        //_logger.trace()
        
        _photos = _album?.photos ?? []
        _photosResult = _album?.result
        
        // 更新.
        collectionView?.reloadData()
        
        guard !_photos.isEmpty else {
            _updateStatus(.notData)
            return
        }
        
        _updateStatus(.notError)
    }
    fileprivate func _clearPhotos() {
        _logger.trace()
        
        // 清空
        _album = nil
        _reloadPhotos()
    }
    
    init(picker: SAPhotoPickerForImp, album: SAPhotoAlbum) {
        super.init(collectionViewLayout: {
            let layout = SAPhotoPickerForAssetsLayout()
            
            layout.itemSize = CGSize(width: 78, height: 78)
            layout.minimumLineSpacing = 2
            layout.minimumInteritemSpacing = 2
            layout.headerReferenceSize = CGSize(width: 0, height: 10)
            layout.footerReferenceSize = CGSize.zero
        
            return layout
        }())
        logger.trace()
        
        _album = album
        
        self.title = album.title
        self.picker = picker
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: nil, action: nil)
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not imp")
    }
    deinit {
        logger.trace()
    }
    
    
    fileprivate var _itemSize: CGSize = .zero
    fileprivate var _columnCount: Int = 0
    fileprivate var _minimumLineSpacing: CGFloat = 0
    fileprivate var _minimumInteritemSpacing: CGFloat = 0
    fileprivate var _cacheBounds: CGRect?
    
    private var _batchEndIndex: Int?
    private var _batchStartIndex: Int?
    private var _batchIsSelectOperator: Bool? // true选中操作，false取消操作
    private var _batchOperatorItems: Set<Int> = []

    private var _status: SAPhotoStatus = .notError
    private var _statusView: SAPhotoErrorView?
    
    private var _toolbarItems: [UIBarButtonItem]??
    
    
    fileprivate var _album: SAPhotoAlbum?
    
    fileprivate var _photos: [SAPhoto] = []
    fileprivate var _photosResult: PHFetchResult<PHAsset>?
    
}

// MARK: - UICollectionViewDelegateFlowLayout

extension SAPhotoPickerForAssets: UICollectionViewDelegateFlowLayout {
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return _photos.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return collectionView.dequeueReusableCell(withReuseIdentifier: "Item", for: indexPath)
    }
    
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? SAPhotoPickerForAssetsCell else {
            return
        }
        cell.delegate = self
        cell.album = _album
        cell.photo = _photos[indexPath.item]
        cell.allowsSelection = allowsMultipleSelection
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else {
            return .zero
        }
        let rect = UIEdgeInsetsInsetRect(collectionView.bounds, collectionView.contentInset)
        guard _cacheBounds?.width != rect.width else {
            return _itemSize
        }
        let mis = layout.minimumInteritemSpacing
        let size = layout.itemSize
        
        let column = Int((rect.width + mis) / (size.width + mis))
        let fcolumn = CGFloat(column)
        let width = trunc(((rect.width + mis) / fcolumn) - mis)
        
        _cacheBounds = rect
        _columnCount = column
        _minimumInteritemSpacing = (rect.width - width * fcolumn) / (fcolumn - 1)
        _minimumLineSpacing = _minimumInteritemSpacing
        _itemSize = CGSize(width: width, height: width)
        
        return _itemSize
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        
        return _minimumLineSpacing
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return _minimumInteritemSpacing
    }
}

// MARK: - SAPhotoViewDelegate(Forwarding)

extension SAPhotoPickerForAssets: SAPhotoSelectionable {
    
    /// gets the index of the selected item, if item does not select to return NSNotFound
    public func selection(_ selection: Any, indexOfSelectedItemsFor photo: SAPhoto) -> Int {
        return self.selection?.selection(self, indexOfSelectedItemsFor: photo) ?? NSNotFound
    }
   
    // check whether item can select
    public func selection(_ selection: Any, shouldSelectItemFor photo: SAPhoto) -> Bool {
        return self.selection?.selection(self, shouldSelectItemFor: photo) ?? true
    }
    public func selection(_ selection: Any, didSelectItemFor photo: SAPhoto) {
        _logger.trace()
        
        self.selection?.selection(self, didSelectItemFor: photo)
        self._updateSelection(forSelected: photo)
    }
    
    // check whether item can deselect
    public func selection(_ selection: Any, shouldDeselectItemFor photo: SAPhoto) -> Bool {
        return self.selection?.selection(self, shouldDeselectItemFor: photo) ?? true
    }
    public func selection(_ selection: Any, didDeselectItemFor photo: SAPhoto) {
        _logger.trace()
        
        self.selection?.selection(self, didDeselectItemFor: photo)
        self._updateSelection(forDeselected: photo)
    }
    
    // tap item
    public func selection(_ selection: Any, tapItemFor photo: SAPhoto, with sender: Any) {
        _logger.trace()
        
        self.selection?.selection(self, tapItemFor: photo, with: sender)
    }
}

// MARK: - PHPhotoLibraryChangeObserver

extension SAPhotoPickerForAssets: PHPhotoLibraryChangeObserver {
    
    public func photoLibraryDidChange(_ changeInstance: PHChange) {
        // 检查有没有变更
        guard let result = _photosResult, let change = changeInstance.changeDetails(for: result), change.hasIncrementalChanges else {
            // 如果asset没有变更, 检查album是否存在
            if let album = _album, !SAPhotoAlbum.albums.contains(album) {
                DispatchQueue.main.async {
                    self._clearPhotos()
                }
            }
            return
        }
        
        let inserts = change.insertedIndexes?.map { idx -> IndexPath in
            return IndexPath(item: idx, section: 0)
        } ?? []
        let changes = change.changedObjects.flatMap { asset -> IndexPath? in
            if let idx = _photos.index(where: { $0.asset.localIdentifier == asset.localIdentifier }) {
                return IndexPath(item: idx, section: 0)
            }
            return nil
        }
        let removes = change.removedObjects.flatMap { asset -> IndexPath? in
            if let idx = _photos.index(where: { $0.asset.localIdentifier == asset.localIdentifier }) {
                return IndexPath(item: idx, section: 0)
            }
            return nil
        }
        
        _album?.clearCache()
        _photosResult = change.fetchResultAfterChanges
        
        DispatchQueue.main.async {
            self._updateContentView(change.fetchResultAfterChanges, inserts, changes, removes)
        }
    }
}
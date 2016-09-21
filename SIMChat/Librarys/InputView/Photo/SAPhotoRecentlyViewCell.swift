//
//  SAPhotoRecentlyViewCell.swift
//  SIMChat
//
//  Created by sagesse on 9/20/16.
//  Copyright © 2016 sagesse. All rights reserved.
//

import UIKit
    

internal class SAPhotoRecentlyViewCell: UICollectionViewCell {
    
    var photo: SAPhoto? {
        set { return _photoView.photo = newValue }
        get { return _photoView.photo }
    }
    
    weak var delegate: SAPhotoViewDelegate? {
        set { return _photoView.delegate = newValue }
        get { return _photoView.delegate }
    }
    
    func updateEdge() {
        _photoView.updateEdge()
    }
    func updateIndex() {
        _photoView.updateIndex()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateEdge()
    }
    
    private func _init() {
        
        _photoView.frame = bounds
        _photoView.allowsSelection = true
        _photoView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        addSubview(_photoView)
    }
    
    private lazy var _photoView: SAPhotoView = SAPhotoView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        _init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        _init()
    }
}

//
//  SAPhotoPickerForPreviewerCellOfImage.swift
//  SIMChat
//
//  Created by sagesse on 26/10/2016.
//  Copyright © 2016 sagesse. All rights reserved.
//

import UIKit

internal class SAPhotoPickerForPreviewerCellOfImage: SAPhotoPickerForPreviewerCell {
    
    override var photo: SAPhoto? {
        willSet {
            _imageView.image = newValue?.image?.withOrientation(orientation)
        }
    }
    
    override var contentView: UIView {
        return _imageView
    }
    
    override func containterViewDidEndRotationing(_ containterView: SAPhotoContainterView, with view: UIView?, atOrientation orientation: UIImageOrientation) {
        super.containterViewDidEndRotationing(containterView, with: view, atOrientation: orientation)
        // 更新图片
        _imageView.image = _imageView.image?.withOrientation(orientation)
    }
    
    private lazy var _imageView: SAPhotoImageView = SAPhotoImageView()
}

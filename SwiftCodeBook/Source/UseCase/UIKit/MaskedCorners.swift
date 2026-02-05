//
//  MaskedCorners.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/4/12.
//

import UIKit

@MainActor
private func MaskedCorners() {
    let view = UIView()
    
    view.layer.cornerRadius = 8
    
    // 只给右下角和右上角加上圆角效果
    view.layer.maskedCorners = [.layerMaxXMaxYCorner, .layerMaxXMinYCorner]
}

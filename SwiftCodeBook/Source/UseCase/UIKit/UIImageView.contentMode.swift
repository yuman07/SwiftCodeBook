//
//  UIImageView.contentMode.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/12/17.
//

import UIKit

func contentMode() {
    let imageView = UIImageView()
    
    // 是将图片按照整个区域进行拉伸
    // 优点：保证图片完整显示，且充满整个区域
    // 缺点：图片可能会失去原有比例而变形
    imageView.contentMode = .scaleToFill
    
    // 是将图片按照区域等比拉伸，直至长或宽首次与区域相切
    // 优点：保证图片完整显示，且不会失去比例变形
    // 缺点：区域不会填充满，可能会有留白
    imageView.contentMode = .scaleAspectFit
    
    // 是将图片按照区域等比拉伸，且长或宽二次与区域相切
    // 优点：保证填充整个区域且图片不会变形
    // 缺点：图片将有一部分超出区域
    // 注意：如果选用AspectFill，该view需要设置clipsToBounds为YES，否则会超过区域
    imageView.contentMode = .scaleAspectFill
}

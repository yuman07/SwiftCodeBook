//
//  UIBezierPath+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import SwiftUI

public extension UIBezierPath {
    // https://github.com/Tencent/QMUI_iOS/blob/master/QMUIKit/UIKitExtensions/UIBezierPath%2BQMUI.h
    convenience init(size: CGSize, rectangleCornerRadii: RectangleCornerRadii) {
        self.init()
        
        let rect = CGRect(origin: .zero, size: size)
        move(to: CGPoint(x: rectangleCornerRadii.topLeading, y: 0))
        addArc(
            withCenter: CGPoint(x: rectangleCornerRadii.topLeading, y: rectangleCornerRadii.topLeading),
            radius: rectangleCornerRadii.topLeading,
            startAngle: .pi * 1.5,
            endAngle: .pi,
            clockwise: false
        )
        
        addLine(to: CGPoint(x: 0, y: rect.height - rectangleCornerRadii.bottomLeading))
        addArc(
            withCenter: CGPoint(x: rectangleCornerRadii.bottomLeading, y: rect.height - rectangleCornerRadii.bottomLeading),
            radius: rectangleCornerRadii.bottomLeading,
            startAngle: .pi,
            endAngle: .pi * 0.5,
            clockwise: false
        )
        
        addLine(to: CGPoint(x: rect.width - rectangleCornerRadii.bottomTrailing, y: rect.height))
        addArc(
            withCenter: CGPoint(x: rect.width - rectangleCornerRadii.bottomTrailing, y: rect.height - rectangleCornerRadii.bottomTrailing),
            radius: rectangleCornerRadii.bottomTrailing,
            startAngle: .pi * 0.5,
            endAngle: 0,
            clockwise: false
        )
        
        addLine(to: CGPoint(x: rect.width, y: rectangleCornerRadii.topTrailing))
        addArc(
            withCenter: CGPoint(x: rect.width - rectangleCornerRadii.topTrailing, y: rectangleCornerRadii.topTrailing),
            radius: rectangleCornerRadii.topTrailing,
            startAngle: 0,
            endAngle: .pi * 1.5,
            clockwise: false
        )
        close()
    }
}

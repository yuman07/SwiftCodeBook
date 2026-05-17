//
//  UIBezierPath+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

#if canImport(UIKit)
import SwiftUI
import UIKit

public extension UIBezierPath {
    // https://github.com/Tencent/QMUI_iOS/blob/master/QMUIKit/UIKitExtensions/UIBezierPath%2BQMUI.h
    convenience init(size: CGSize, rectangleCornerRadii: RectangleCornerRadii) {
        self.init()
        
        let rect = CGRect(origin: .zero, size: size)
        let maxRadius = max(0, min(size.width, size.height) / 2)
        let topLeading = max(0, min(rectangleCornerRadii.topLeading, maxRadius))
        let topTrailing = max(0, min(rectangleCornerRadii.topTrailing, maxRadius))
        let bottomLeading = max(0, min(rectangleCornerRadii.bottomLeading, maxRadius))
        let bottomTrailing = max(0, min(rectangleCornerRadii.bottomTrailing, maxRadius))
        
        move(to: CGPoint(x: topLeading, y: 0))
        addArc(
            withCenter: CGPoint(x: topLeading, y: topLeading),
            radius: topLeading,
            startAngle: .pi * 1.5,
            endAngle: .pi,
            clockwise: false
        )

        addLine(to: CGPoint(x: 0, y: rect.height - bottomLeading))
        addArc(
            withCenter: CGPoint(x: bottomLeading, y: rect.height - bottomLeading),
            radius: bottomLeading,
            startAngle: .pi,
            endAngle: .pi * 0.5,
            clockwise: false
        )

        addLine(to: CGPoint(x: rect.width - bottomTrailing, y: rect.height))
        addArc(
            withCenter: CGPoint(x: rect.width - bottomTrailing, y: rect.height - bottomTrailing),
            radius: bottomTrailing,
            startAngle: .pi * 0.5,
            endAngle: 0,
            clockwise: false
        )

        addLine(to: CGPoint(x: rect.width, y: topTrailing))
        addArc(
            withCenter: CGPoint(x: rect.width - topTrailing, y: topTrailing),
            radius: topTrailing,
            startAngle: 0,
            endAngle: .pi * 1.5,
            clockwise: false
        )
        close()
    }
}
#endif

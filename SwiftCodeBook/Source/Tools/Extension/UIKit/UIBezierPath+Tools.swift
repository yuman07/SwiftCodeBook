//
//  UIBezierPath+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import UIKit

public extension UIBezierPath {
    // https://github.com/Tencent/QMUI_iOS/blob/master/QMUIKit/UIKitExtensions/UIBezierPath%2BQMUI.h
    convenience init(size: CGSize, cornerRadius: (topLeft: CGFloat, bottomLeft: CGFloat, bottomRight: CGFloat, topRight: CGFloat)) {
        self.init()
        
        let rect = CGRect(origin: .zero, size: size)
        move(to: CGPoint(x: cornerRadius.topLeft, y: 0))
        addArc(
            withCenter: CGPoint(x: cornerRadius.topLeft, y: cornerRadius.topLeft),
            radius: cornerRadius.topLeft,
            startAngle: .pi * 1.5,
            endAngle: .pi,
            clockwise: false
        )
        
        addLine(to: CGPoint(x: 0, y: rect.height - cornerRadius.bottomLeft))
        addArc(
            withCenter: CGPoint(x: cornerRadius.bottomLeft, y: rect.height - cornerRadius.bottomLeft),
            radius: cornerRadius.bottomLeft,
            startAngle: .pi,
            endAngle: .pi * 0.5,
            clockwise: false
        )
        
        addLine(to: CGPoint(x: rect.width - cornerRadius.bottomRight, y: rect.height))
        addArc(
            withCenter: CGPoint(x: rect.width - cornerRadius.bottomRight, y: rect.height - cornerRadius.bottomRight),
            radius: cornerRadius.bottomRight,
            startAngle: .pi * 0.5,
            endAngle: 0,
            clockwise: false
        )
        
        addLine(to: CGPoint(x: rect.width, y: cornerRadius.topRight))
        addArc(
            withCenter: CGPoint(x: rect.width - cornerRadius.topRight, y: cornerRadius.topRight),
            radius: cornerRadius.topRight,
            startAngle: 0,
            endAngle: .pi * 1.5,
            clockwise: false
        )
        close()
    }
}

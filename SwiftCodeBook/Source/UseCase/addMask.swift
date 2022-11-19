//
//  addMask.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/19.
//

import UIKit

func makeMaskView() -> UIView {
    let view = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
    let layer = CAShapeLayer()
    let path = UIBezierPath()
    path.move(to: .zero)
    path.addLine(to: CGPoint(x: 200, y: 0))
    path.addLine(to: CGPoint(x: 100, y: 100))
    path.close()
    layer.path = path.cgPath
    view.layer.mask = layer
    view.backgroundColor = .red
    return view
}

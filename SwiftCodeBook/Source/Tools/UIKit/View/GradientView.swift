//
//  GradientView.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import UIKit

public final class GradientView: UIView {
    public override class var layerClass: AnyClass {
        CAGradientLayer.self
    }
    
    // point的坐标系和UIKit相同，且取值范围是[0, 1]
    // 即(0, 0)代表左上角，(1, 1)代表右下角
    public func updateGradient(startPoint: CGPoint, endPoint: CGPoint, startColor: UIColor, endColor: UIColor) {
        guard let layer = layer as? CAGradientLayer else { return }
        layer.startPoint = startPoint
        layer.endPoint = endPoint
        layer.colors = [startColor.cgColor, endColor.cgColor]
    }
}

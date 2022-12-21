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
    
    public func updateGradient(startPoint: CGPoint, endPoint: CGPoint, startColor: UIColor, endColor: UIColor) {
        guard let layer = self.layer as? CAGradientLayer else { return }
        layer.startPoint = startPoint
        layer.endPoint = endPoint
        layer.colors = [startColor.cgColor, endColor.cgColor]
    }
}

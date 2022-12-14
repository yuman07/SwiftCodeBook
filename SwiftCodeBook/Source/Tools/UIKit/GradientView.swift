//
//  GradientView.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import UIKit

final class GradientView: UIView {
    override class var layerClass: AnyClass {
        CAGradientLayer.self
    }
    
    func updateGradient(startPoint: CGPoint, endPoint: CGPoint, startColor: UIColor, endColor: UIColor) {
        guard let layer = self.layer as? CAGradientLayer else { return }
        layer.startPoint = startPoint
        layer.endPoint = endPoint
        layer.colors = [startColor.cgColor, endColor.cgColor]
    }
}

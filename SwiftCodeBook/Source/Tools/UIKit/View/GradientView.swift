//
//  GradientView.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import UIKit

// point的坐标系和UIKit相同，且取值范围是[0, 1]
// 即(0, 0)代表左上角，(1, 1)代表右下角
public final class GradientView: UIView {
    public override class var layerClass: AnyClass {
        CAGradientLayer.self
    }
    
    private var gradientLayer: CAGradientLayer {
        guard let layer = layer as? CAGradientLayer else {
            fatalError("layer must be CAGradientLayer")
        }
        return layer
    }
    
    /// same with CAGradientLayer.colors
    public var colors: [UIColor] {
        get { (gradientLayer.colors as? [CGColor] ?? []).map { UIColor(cgColor: $0) } }
        set { gradientLayer.colors = newValue.map(\.cgColor) }
    }
    
    /// same with CAGradientLayer.locations
    public var locations: [CGFloat] {
        get { (gradientLayer.locations ?? []).map(\.cgFloatValue) }
        set { gradientLayer.locations = newValue.map { NSNumber(value: $0) } }
    }
    
    /// same with CAGradientLayer.startPoint
    public var startPoint: CGPoint {
        get { gradientLayer.startPoint }
        set { gradientLayer.startPoint = newValue }
    }
    
    /// same with CAGradientLayer.endPoint
    public var endPoint: CGPoint {
        get { gradientLayer.endPoint }
        set { gradientLayer.endPoint = newValue }
    }
    
    /// same with CAGradientLayer.type
    public var type: CAGradientLayerType {
        get { gradientLayer.type }
        set { gradientLayer.type = newValue }
    }
}

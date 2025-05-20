//
//  UIImage+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import UIKit

public extension UIImage {
    static func color(_ color: UIColor, size: CGSize = .one) -> UIImage {
        UIGraphicsImageRenderer(size: size.validSelfOrOne).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    static func snapshotView(_ uiView: UIView, afterScreenUpdates: Bool = false) -> UIImage {
        UIGraphicsImageRenderer(size: uiView.bounds.size).image {
            if !afterScreenUpdates {
                uiView.layer.render(in: $0.cgContext)
            } else {
                uiView.drawHierarchy(in: uiView.bounds, afterScreenUpdates: true)
            }
        }
    }
    
    convenience init?(filePath: String) {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else { return nil }
        self.init(data: data)
    }
    
    convenience init?(symbolName: String, pointSize: CGFloat) {
        guard pointSize.isFinite else { return nil }
        self.init(systemName: symbolName, withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize))
    }
    
    var sizeInByte: UInt64 {
        let bytesPerFrame = UInt64(cgImage?.bytesPerRow ?? 0)
        let frameCount = UInt64(images.flatMap { $0.count > 0 ? $0.count : 1 } ?? 1)
        return bytesPerFrame * frameCount
    }
}

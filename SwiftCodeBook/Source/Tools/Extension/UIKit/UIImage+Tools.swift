//
//  UIImage+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

#if canImport(UIKit)
import UIKit

public extension UIImage {
    // TODO: watchos
    static func color(_ color: UIColor, size: CGSize = .one) -> UIImage {
        UIGraphicsImageRenderer(size: size.validSelfOrOne).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    // TODO: watchos
    func fixOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        return UIGraphicsImageRenderer(size: size, format: imageRendererFormat).image { _ in
            draw(at: .zero)
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
}
#endif

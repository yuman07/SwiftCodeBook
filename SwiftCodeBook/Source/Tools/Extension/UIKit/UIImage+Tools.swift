//
//  UIImage+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

#if canImport(UIKit)
import UIKit

public extension UIImage {
    static func color(_ color: UIColor, size: CGSize = .one) -> UIImage {
#if os(iOS) || os(tvOS) || os(visionOS)
        UIGraphicsImageRenderer(size: size.validSelfOrOne).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
#else
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
#endif
    }
    
    func fixOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
#if os(iOS) || os(tvOS) || os(visionOS)
        return UIGraphicsImageRenderer(size: size, format: imageRendererFormat).image { _ in
            draw(at: .zero)
        }
#else
        UIGraphicsBeginImageContextWithOptions(size, imageRendererFormat.opaque, imageRendererFormat.scale)
        defer { UIGraphicsEndImageContext() }
        draw(at: .zero)
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
#endif
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

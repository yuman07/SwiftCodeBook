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
        let realSize = size.validSelfOrOne
        return UIGraphicsImageRenderer(size: realSize).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: realSize))
        }
#else
        let realSize = size.validSelfOrOne
        UIGraphicsBeginImageContext(realSize)
        defer { UIGraphicsEndImageContext() }
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: realSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
#endif
    }
    
    func fixOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
#if os(iOS) || os(tvOS) || os(visionOS)
        return UIGraphicsImageRenderer(size: size, format: imageRendererFormat).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
#else
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
#endif
    }
    
    convenience init?(filePath: String) {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else { return nil }
        self.init(data: data)
    }
    
    convenience init?(symbolName: String, pointSize: CGFloat) {
        guard pointSize.isFinite, pointSize > 0 else { return nil }
        self.init(systemName: symbolName, withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize))
    }
}
#endif

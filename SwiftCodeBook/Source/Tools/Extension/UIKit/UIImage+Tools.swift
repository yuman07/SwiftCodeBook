//
//  UIImage+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import UIKit

public extension UIImage {
    convenience init(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) {
        guard let cgImage = UIGraphicsImageRenderer(size: size).image(actions: { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }).cgImage else { fatalError("UIImage.init(color:size:) fail, cgImage not exist") }
        self.init(cgImage: cgImage, scale: UITraitCollection.current.displayScale, orientation: .up)
    }
    
    convenience init?(filePath: String) {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else { return nil }
        self.init(data: data)
    }
    
    convenience init?(symbolName: String, size: CGFloat) {
        self.init(systemName: symbolName, withConfiguration: UIImage.SymbolConfiguration(pointSize: size))
    }
    
    var sizeInByte: UInt64 {
        let bytesPerFrame = UInt64(cgImage?.bytesPerRow ?? 0)
        let frameCount = UInt64(images.flatMap { $0.count > 0 ? $0.count : 1 } ?? 1)
        return bytesPerFrame * frameCount
    }
}

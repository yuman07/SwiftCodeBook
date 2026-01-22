//
//  UIFont+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/3/28.
//

#if canImport(UIKit)
import UIKit

public extension UIFont {
    // bold: addTraits(.traitBold)
    // boldAndItalic: addTraits([.traitBold, .traitItalic])
    func addTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(fontDescriptor.symbolicTraits.union(traits)) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
    
    func removeTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(fontDescriptor.symbolicTraits.subtracting(traits)) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
    
    // isBold: containsTraits(.traitBold)
    func containsTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> Bool {
        fontDescriptor.symbolicTraits.contains(traits)
    }
}
#endif

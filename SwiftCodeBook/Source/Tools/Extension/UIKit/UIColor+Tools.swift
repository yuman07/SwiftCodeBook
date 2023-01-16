//
//  UIColor+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import UIKit

public extension UIColor {
    convenience init?(RGBA: String) {
        guard RGBA.first == "#" && (RGBA.count == 7 || RGBA.count == 9) else { return nil }
        var hexNum = UInt64.zero
        let target = "\(RGBA.suffix(RGBA.count - 1))" + (RGBA.count == 7 ? "FF" : "")
        guard case let s = Scanner(string: target), s.scanHexInt64(&hexNum) && s.isAtEnd else { return nil }
        self.init(red: CGFloat((hexNum & 0xff000000) >> 24) / 255,
                  green: CGFloat((hexNum & 0x00ff0000) >> 16) / 255,
                  blue: CGFloat((hexNum & 0x0000ff00) >> 8) / 255,
                  alpha: CGFloat(hexNum & 0x000000ff) / 255)
    }
    
    var rgba: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var r = CGFloat.zero
        var g = CGFloat.zero
        var b = CGFloat.zero
        var a = CGFloat.zero
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }
}

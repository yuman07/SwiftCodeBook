//
//  UIColor+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import UIKit

extension UIColor {
    convenience init?(RGBA: String) {
        guard RGBA[RGBA.startIndex] == "#" && (RGBA.count == 7 || RGBA.count == 9) else { return nil }
        
        var hexNum = UInt64.zero
        let target = "\(RGBA.suffix(RGBA.count - 1))" + (RGBA.count == 7 ? "FF" : "" )
        guard case let s = Scanner(string: target), s.scanHexInt64(&hexNum) && s.isAtEnd else { return nil }
        let r = CGFloat((hexNum & 0xff000000) >> 24) / 255
        let g = CGFloat((hexNum & 0x00ff0000) >> 16) / 255
        let b = CGFloat((hexNum & 0x0000ff00) >> 8) / 255
        let a = CGFloat(hexNum & 0x000000ff) / 255
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

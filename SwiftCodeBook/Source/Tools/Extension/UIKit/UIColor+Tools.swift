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
        let target = "\(RGBA.dropFirst())" + (RGBA.count == 7 ? "FF" : "")
        guard case let s = Scanner(string: target), s.scanHexInt64(&hexNum) && s.isAtEnd else { return nil }
        self.init(
            red: CGFloat((hexNum & 0xff000000) >> 24) / 255,
            green: CGFloat((hexNum & 0x00ff0000) >> 16) / 255,
            blue: CGFloat((hexNum & 0x0000ff00) >> 8) / 255,
            alpha: CGFloat(hexNum & 0x000000ff) / 255
        )
    }
    
    var rgba: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var r = CGFloat.zero
        var g = CGFloat.zero
        var b = CGFloat.zero
        var a = CGFloat.zero
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }
    
    var rgbaString: String {
        let rgba = rgba
        let r = String(Int(round(rgba.red * 255.0)), radix: 16, uppercase: true)
        let g = String(Int(round(rgba.green * 255.0)), radix: 16, uppercase: true)
        let b = String(Int(round(rgba.blue * 255.0)), radix: 16, uppercase: true)
        let a = rgba.alpha == 1 ? "" : String(Int(round(rgba.alpha * 255.0)), radix: 16, uppercase: true)
        return [r, g, b, a].reduce(into: "#") { partialResult, hex in
            partialResult += hex.count == 1 ? "0\(hex)" : hex
        }
    }
}

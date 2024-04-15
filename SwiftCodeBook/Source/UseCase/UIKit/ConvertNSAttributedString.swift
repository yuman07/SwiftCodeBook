//
//  ConvertNSAttributedString.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/4/15.
//

import UIKit
import SwiftUI

// 测试可以发现：NSAttributedString.Key 与 AttributeScopes.SwiftUIAttributes.FontAttribute 不是等价的，两者在NSAttributedString转换时会同时保留。
// 且NSAttributedString与AttributedString只会认对应的Key，因此String转换后对于Key仍需要手动遍历转换
func testConvertNSAttributedString() {
    let string = "你好123哈哈哈"
    let nsAttributedString = NSMutableAttributedString(string: string)
    nsAttributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 17), range: NSRange(location: 2, length: 3))
    nsAttributedString.addAttribute(.foregroundColor, value: UIColor.red, range: NSRange(location: 5, length: 3))
    
    print(nsAttributedString)
    
    var attributedString = AttributedString(nsAttributedString)
    print("--------------")
    print(attributedString)
    
    if let range = Range(NSRange(location: 2, length: 3), in: attributedString) {
        attributedString[range].font = Font(UIFont.systemFont(ofSize: 17))
    }
    if let range = Range(NSRange(location: 5, length: 3), in: attributedString) {
        attributedString[range].foregroundColor = Color(UIColor.red)
    }
    
    print("--------------")
    print(attributedString)
    
    // NSAttributedString.Key -> AttributeScopes.SwiftUIAttributes.FontAttribute
    nsAttributedString.enumerateAttribute(.font, in: NSRange(location: 0, length: nsAttributedString.length)) { value, range, _ in
        if let range = Range(range, in: attributedString), let font = value as? UIFont {
            attributedString[range].font = Font(font)
        }
    }
    
    // AttributeScopes.SwiftUIAttributes.FontAttribute -> NSAttributedString.Key
    // 注意：Font无法转为UIFont
    for run in attributedString.runs {
        if let color = run.foregroundColor {
            nsAttributedString.addAttribute(.foregroundColor, value: UIColor(color), range: NSRange(run.range, in: attributedString))
        }
    }
}


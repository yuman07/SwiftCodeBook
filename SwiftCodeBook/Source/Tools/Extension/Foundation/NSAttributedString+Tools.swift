//
//  NSAttributedString+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/6/29.
//

import Foundation

public extension NSAttributedString {
    func trimmingCharacters(in characterSet: CharacterSet) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(attributedString: self)
        
        var range = (attributedString.string as NSString).rangeOfCharacter(from: characterSet)
        while range.location == 0 && range.length > 0 {
            attributedString.replaceCharacters(in: range, with: "")
            range = (attributedString.string as NSString).rangeOfCharacter(from: characterSet)
        }
        
        range = (attributedString.string as NSString).rangeOfCharacter(from: characterSet, options: .backwards)
        while NSMaxRange(range) == (attributedString.string as NSString).length && range.length > 0 {
            attributedString.replaceCharacters(in: range, with: "")
            range = (attributedString.string as NSString).rangeOfCharacter(from: characterSet, options: .backwards)
        }
        
        return attributedString
    }
}

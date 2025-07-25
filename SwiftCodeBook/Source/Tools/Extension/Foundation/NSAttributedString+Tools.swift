//
//  NSAttributedString+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/6/29.
//

import Foundation

public extension NSAttributedString {
    var fullRange: NSRange {
        NSRange(location: 0, length: length)
    }

    func trimmingCharacters(in characterSet: CharacterSet) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(attributedString: self)
        var range = NSRange()
        
        while true {
            range = (attributedString.string as NSString).rangeOfCharacter(from: characterSet)
            guard range.location == 0 && range.length > 0 else { break }
            attributedString.deleteCharacters(in: range)
        }
        
        while true {
            range = (attributedString.string as NSString).rangeOfCharacter(from: characterSet, options: .backwards)
            guard NSMaxRange(range) == attributedString.length && range.length > 0 else { break }
            attributedString.deleteCharacters(in: range)
        }
        
        return NSAttributedString(attributedString: attributedString)
    }
}

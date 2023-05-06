//
//  CharacterSet+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/5/6.
//

import Foundation

public extension CharacterSet {
    // https://en.wikipedia.org/wiki/Zero-width_space
    // https://unicode-explorer.com/search/
    static let zeroWidthSpace = CharacterSet(charactersIn: "\u{200B}\u{2060}\u{200C}\u{FEFF}\u{200D}")
    
    static let whitespacesNewlineAndZeroWidthSpace = CharacterSet.whitespacesAndNewlines.union(.zeroWidthSpace)
}

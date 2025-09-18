//
//  Locale+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/4/26.
//

import Foundation

public extension Locale {
    // "en-US"
    var bcp47Identifier: String {
        // Some locale identifiers contain special fields like calendar or numbers, eg: "ar-SA@calendar=gregorian;numbers=latn"
        (identifier.components(separatedBy: "@").first ?? identifier).replacingOccurrences(of: "_", with: "-")
    }
}

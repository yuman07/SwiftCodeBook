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
        let localeIdentifier = identifier.replacingOccurrences(of: "_", with: "-")
        // Some locale identifiers contain special fields like calendar or numbers, eg: "ar-SA@calendar=gregorian;numbers=latn"
        return localeIdentifier.components(separatedBy: "@").first ?? localeIdentifier
    }
}

//
//  LowerFirstLetterKey.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/5/10.
//

import Foundation

public extension JSONDecoder.KeyDecodingStrategy {
    static let lowerFirstLetter = Self.custom { codingPath in
        guard let key = codingPath.last?.stringValue, !key.isEmpty else {
            return codingPath.last ?? AnyKey(stringValue: "")
        }
        return AnyKey(stringValue: String(key.prefix(1)).lowercased() + String(key.dropFirst()))
    }
    
    private struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int?
        
        init(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = Int(stringValue)
        }
        
        init(intValue: Int) {
            self.stringValue = String(intValue)
            self.intValue = intValue
        }
    }
}

//
//  LowerFirstLetterKey.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/5/10.
//

import Foundation

public extension JSONDecoder.KeyDecodingStrategy {
    // 注意这个处理其实并不完美，比如payload: { "id": "111", "Id": 222 }, 这种case就会出现bug
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

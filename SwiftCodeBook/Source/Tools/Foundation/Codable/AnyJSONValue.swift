//
//  AnyJSONValue.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/12/26.
//

import Foundation

// 有些时候在一个Model中我们只知道一个属性是json的一种value，但不知道具体类型，此时可以用AnyJSONValue
public struct AnyJSONValue: Codable {
    private let value: Any
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = NSNull()
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let array = try? container.decode([Self].self) {
            self.value = array
        } else if let dictionary = try? container.decode([String: Self].self) {
            self.value = dictionary
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type found")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let array as [Self]:
            try container.encode(array)
        case let dictionary as [String: Self]:
            try container.encode(dictionary)
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type found"))
        }
    }
}

public extension AnyJSONValue {
    var isNull: Bool {
        value is NSNull
    }
    
    var stringValue: String? {
        value as? String
    }
    
    var intValue: Int? {
        value as? Int
    }
    
    var doubleValue: Double? {
        value as? Double
    }
    
    var boolValue: Bool? {
        value as? Bool
    }
    
    var arrayValue: [Self]? {
        value as? [Self]
    }
    
    var dictionaryValue: [String: Self]? {
        value as? [String: Self]
    }
}

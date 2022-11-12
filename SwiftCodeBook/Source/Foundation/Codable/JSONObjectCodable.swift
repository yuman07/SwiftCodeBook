//
//  JSONObjectCodable.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/12.
//

import Foundation

public struct JSONDictionaryCodable: Codable {
    public var value: [String: Any]
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JSONCodingKeys.self)
        value = try container.decode([String: Any].self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: JSONCodingKeys.self)
        try container.encode(value)
    }
}

public struct JSONArrayCodable: Codable {
    public var value: [Any]
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        value = try container.decode([Any].self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(value)
    }
}

private extension KeyedDecodingContainer where Key == JSONCodingKeys {
    func decode(_ type: [String: Any].Type) throws -> [String: Any] {
        var result = [String: Any]()
        for key in allKeys {
            if let value = try? decode(Int.self, forKey: key) {
                result[key.stringValue] = value
            } else if let value = try? decode(Double.self, forKey: key) {
                result[key.stringValue] = value
            } else if let value = try? decode(Bool.self, forKey: key) {
                result[key.stringValue] = value
            } else if let value = try? decode(String.self, forKey: key) {
                result[key.stringValue] = value
            } else if let value = try? decode([Any].self, forKey: key) {
                result[key.stringValue] = value
            } else if let value = try? decode([String: Any].self, forKey: key) {
                result[key.stringValue] = value
            } else if try decodeNil(forKey: key) {
                result[key.stringValue] = NSNull()
            } else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "decode failed"))
            }
        }
        return result
    }
    
    func decode(_ type: [String: Any].Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> [String: Any] {
        let container = try nestedContainer(keyedBy: JSONCodingKeys.self, forKey: key)
        return try container.decode([String: Any].self)
    }
    
    func decode(_ type: [Any].Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> [Any] {
        var container = try nestedUnkeyedContainer(forKey: key)
        return try container.decode([Any].self)
    }
}

private extension UnkeyedDecodingContainer {
    mutating func decode(_ type: [String: Any].Type) throws -> [String: Any] {
        let container = try nestedContainer(keyedBy: JSONCodingKeys.self)
        return try container.decode([String: Any].self)
    }
    
    mutating func decodeWithNewContainer(_ type: [Any].Type) throws -> [Any] {
        var container = try nestedUnkeyedContainer()
        return try container.decode([Any].self)
    }
    
    mutating func decode(_ type: [Any].Type) throws -> [Any] {
        var result = [Any]()
        while !isAtEnd {
            if let value = try? decode(Int.self) {
                result.append(value)
            } else if let value = try? decode(Double.self) {
                result.append(value)
            } else if let value = try? decode(Bool.self) {
                result.append(value)
            } else if let value = try? decode(String.self) {
                result.append(value)
            } else if let value = try? decodeWithNewContainer([Any].self) {
                result.append(value)
            } else if let value = try? decode([String: Any].self) {
                result.append(value)
            } else if try decodeNil() {
                result.append(NSNull())
            } else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "decode failed"))
            }
        }
        return result
    }
}

private extension KeyedEncodingContainer where Key == JSONCodingKeys {
    mutating func encode(_ value: [String: Any]) throws {
        try value.forEach { (key, value) in
            let key = JSONCodingKeys(stringValue: key)
            switch value {
            case let value as Encodable:
                try encode(value, forKey: key)
            case let value as [String: Any]:
                try encode(value, forKey: key)
            case let value as [Any]:
                try encode(value, forKey: key)
            case is NSNull:
                try encodeNil(forKey: key)
            default:
                throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: codingPath, debugDescription: "encode failed"))
            }
        }
    }
    
    mutating func encode(_ value: [String: Any], forKey key: KeyedEncodingContainer<K>.Key) throws {
        var container = nestedContainer(keyedBy: JSONCodingKeys.self, forKey: key)
        try container.encode(value)
    }
    
    mutating func encode(_ value: [Any], forKey key: KeyedEncodingContainer<K>.Key) throws {
        var container = nestedUnkeyedContainer(forKey: key)
        try container.encode(value)
    }
}

private extension UnkeyedEncodingContainer {
    mutating func encode(_ value: [String: Any]) throws {
        var container = nestedContainer(keyedBy: JSONCodingKeys.self)
        try container.encode(value)
    }
    
    mutating func encodeWithNewContainer(_ value: [Any]) throws {
        var container = nestedUnkeyedContainer()
        try container.encode(value)
    }
    
    mutating func encode(_ value: [Any]) throws {
        try value.forEach { value in
            switch value {
            case let value as Encodable:
                try encode(value)
            case let value as [String: Any]:
                try encode(value)
            case let value as [Any]:
                try encodeWithNewContainer(value)
            case is NSNull:
                try encodeNil()
            default:
                throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: codingPath, debugDescription: "encode failed"))
            }
        }
    }
}

private struct JSONCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
    
    init(stringValue: String) {
        self.stringValue = stringValue
    }
}

//
//  AnyJSONValue.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/12/26.
//

import Foundation

// 有些时候在一个Model中我们只知道一个属性是json的一种value，但不知道具体类型，此时可以用AnyJSONValue
@frozen public enum AnyJSONValue: Codable, Hashable, Sendable {
    case null
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyJSONValue])
    case dictionary([String: AnyJSONValue])
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([AnyJSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: AnyJSONValue].self) {
            self = .dictionary(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON type")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case let .bool(value): try container.encode(value)
        case let .int(value): try container.encode(value)
        case let .double(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case let .dictionary(value): try container.encode(value)
        }
    }
}

public extension AnyJSONValue {
    var isNull: Bool {
        guard case .null = self else { return false }
        return true
    }
    
    var stringValue: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }
    
    var intValue: Int? {
        guard case let .int(value) = self else { return nil }
        return value
    }
    
    var doubleValue: Double? {
        guard case let .double(value) = self else { return nil }
        return value
    }
    
    var boolValue: Bool? {
        guard case let .bool(value) = self else { return nil }
        return value
    }
    
    var arrayValue: [Self]? {
        guard case let .array(value) = self else { return nil }
        return value
    }
    
    var dictionaryValue: [String: Self]? {
        guard case let .dictionary(value) = self else { return nil }
        return value
    }
}

//
//  OptionalCodable.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/11.
//

import Foundation

// 当Model中有一个Array需要Decode时，只要其中有一个item Decode失败，整个Array的Decode就会失败
// 我们有时不需要这个行为，希望如果其中一个item失败那它就是nil即可，不要影响整个Array
public struct OptionalCodable<T: Codable>: Codable {
    public let value: T?
    
    public init(from decoder: Decoder) throws {
        do {
            let container = try decoder.singleValueContainer()
            self.value = try container.decode(T.self)
        } catch {
            self.value = nil
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

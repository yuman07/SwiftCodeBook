//
//  OptionalDecodable.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/11.
//

import Foundation

// When decoding an array, the default behavior is that as long as any item in the array fails to decode, the entire array will be considered a failure.
// To prevent this and filter out items that fail to decode, use this
// Use case reference OptionalDecodableTest.swift
struct OptionalDecodable<T: Decodable>: Decodable {
    let value: T?
    
    init(from decoder: Decoder) throws {
        do {
            let container = try decoder.singleValueContainer()
            self.value = try container.decode(T.self)
        } catch {
            self.value = nil
        }
    }
}

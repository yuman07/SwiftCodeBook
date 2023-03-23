//
//  JSONDecoder.DateDecodingStrategy+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/3/22.
//

import Foundation

public extension JSONDecoder.DateDecodingStrategy {
    static var ISO8601Decode: JSONDecoder.DateDecodingStrategy {
        .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = ISO8601DateFormatter.date(from: string) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(string)")
            }
            return date
        }
    }
}

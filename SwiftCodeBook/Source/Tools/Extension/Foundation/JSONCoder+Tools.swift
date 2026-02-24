//
//  JSONCoder+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2026/2/24.
//

import Foundation

public extension JSONDecoder.DateDecodingStrategy {
    static var ISO8601Decode: JSONDecoder.DateDecodingStrategy {
        .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = ISO8601DateFormatter.date(from: string) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode ISO8601 date string \(string)")
            }
            return date
        }
    }
}

public extension JSONEncoder.DateEncodingStrategy {
    static func ISO8601Encode(options: ISO8601DateFormatter.Options = [.withTimeZone, .withFractionalSeconds]) -> JSONEncoder.DateEncodingStrategy {
        .custom { date, encoder in
            let string = ISO8601DateFormatter.string(from: date, options: options)
            var container = encoder.singleValueContainer()
            try container.encode(string)
        }
    }
}


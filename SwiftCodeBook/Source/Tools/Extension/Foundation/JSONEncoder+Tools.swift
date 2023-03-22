//
//  JSONEncoder+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/3/22.
//

import Foundation

public extension JSONEncoder.DateEncodingStrategy {
    static func ISO8601Encode(options: ISO8601DateFormatter.Options = [.withTimeZone, .withFractionalSeconds]) -> JSONEncoder.DateEncodingStrategy {
        .custom { date, encoder in
            let string = ISO8601DateFormatter.string(from: date, options: options)
            var container = encoder.singleValueContainer()
            try container.encode(string)
        }
    }
}

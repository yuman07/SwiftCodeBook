//
//  ISO8601DateFormatter+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/2/16.
//

import Foundation

public extension ISO8601DateFormatter {
    static func date(from string: String) -> Date? {
        for formatter in formatters.reversed() {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }
    
    static func string(from date: Date, options: ISO8601DateFormatter.Options = [.withTimeZone, .withFractionalSeconds]) -> String {
        var index = 0
        for (idx, value) in optionals.enumerated() where options.contains(value) {
            index += (1 << idx)
        }
        return formatters[index].string(from: date)
    }
    
    private static let basic: ISO8601DateFormatter.Options = [.withYear, .withMonth, .withDay, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withColonSeparatorInTimeZone]
    
    private static let optionals: [ISO8601DateFormatter.Options] = [.withTimeZone, .withFractionalSeconds]
    
    private static let formatters = {
        (0 ..< 1 << optionals.count).map { num -> ISO8601DateFormatter in
            var formatOptions = basic
            for (index, value) in optionals.enumerated() where (num >> index) & 1 == 1 {
                formatOptions.insert(value)
            }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = formatOptions
            return formatter
        }
    }()
}

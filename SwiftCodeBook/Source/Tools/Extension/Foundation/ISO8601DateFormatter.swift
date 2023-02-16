//
//  ISO8601DateFormatter.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/2/16.
//

import Foundation

public extension ISO8601DateFormatter {
    static func date(from string: String) -> Date? {
        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }
    
    static func string(from date: Date) -> String {
        formatters[3].string(from: date)
    }
    
    private static let formatters = {
        let defaults: ISO8601DateFormatter.Options =
        [.withYear, .withMonth, .withDay, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withColonSeparatorInTimeZone]
        
        let optionals: [ISO8601DateFormatter.Options] =
        [.withTimeZone, .withFractionalSeconds, .withSpaceBetweenDateAndTime]
        
        return (0 ..< 2 << (optionals.count - 1)).map { num -> ISO8601DateFormatter in
            var formatOptions = defaults
            optionals.enumerated().forEach { index, value in
                if (num >> index) & 1 == 1 { formatOptions.insert(value) }
            }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = formatOptions
            return formatter
        }
    }()
}

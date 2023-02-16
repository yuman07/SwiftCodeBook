//
//  DateFormatter+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

public extension DateFormatter {
    static func dateWithISO8601String(_ ISO8601String: String) -> Date? {
        for formatter in formatters {
            if let date = formatter.date(from: ISO8601String) {
                return date
            }
        }
        return nil
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

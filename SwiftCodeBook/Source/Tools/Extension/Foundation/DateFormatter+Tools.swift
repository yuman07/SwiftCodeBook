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
        let options: [ISO8601DateFormatter.Options] = [.withTimeZone, .withFractionalSeconds, .withSpaceBetweenDateAndTime]
        return (0 ..< 2 << (options.count - 1)).reduce(into: [ISO8601DateFormatter]()) { partialResult, num in
            let formatter = ISO8601DateFormatter()
            var formatOptions = formatter.formatOptions
            formatOptions.remove(.withTimeZone)
            options.enumerated().forEach { index, value in
                if (num >> index) & 1 == 1 {
                    formatOptions.insert(value)
                }
            }
            formatter.formatOptions = formatOptions
            partialResult.append(formatter)
        }
    }()
}

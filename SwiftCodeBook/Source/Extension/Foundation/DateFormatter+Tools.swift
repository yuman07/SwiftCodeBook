//
//  DateFormatter+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

public extension DateFormatter {
    static func dateWithISO8601Format(_ ISO8601Str: String) -> Date? {
        for formatter in formatters {
            if let date = formatter.date(from: ISO8601Str) {
                return date
            }
        }
        return nil
    }
    
    private static let kUSPosixLocaleID = "en_US_POSIX"
    private static let formatters: [DateFormatter] = [
        {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
            formatter.calendar = Calendar(identifier: .iso8601)
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.locale = Locale(identifier: kUSPosixLocaleID)
            return formatter
        }(),
        {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            formatter.calendar = Calendar(identifier: .iso8601)
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.locale = Locale(identifier: kUSPosixLocaleID)
            return formatter
        }(),
        {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            formatter.calendar = Calendar(identifier: .iso8601)
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.locale = Locale(identifier: kUSPosixLocaleID)
            return formatter
        }()
    ]
}

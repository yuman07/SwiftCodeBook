//
//  DateFormatter+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/8/16.
//

import Foundation

public extension DateFormatter {
    struct Format: Hashable, Sendable {
        public let dateFormat: String
        public let locale: Locale
        public let timeZone: TimeZone
        
        public init(dateFormat: String, locale: Locale = .current, timeZone: TimeZone = .current) {
            self.dateFormat = dateFormat
            self.locale = locale
            self.timeZone = timeZone
        }
    }
    
    private static let dateFormatterMap = MemoryCache<DateFormatter.Format, DateFormatter>()
    
    private static func dateFormatter(with format: DateFormatter.Format) -> DateFormatter {
        if let dateFormatter = dateFormatterMap.value(forKey: format) {
            return dateFormatter
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format.dateFormat
        dateFormatter.locale = format.locale
        dateFormatter.timeZone = format.timeZone
        dateFormatterMap.setValue(dateFormatter, forKey: format)
        return dateFormatter
    }
    
    static func string(from date: Date, format: DateFormatter.Format) -> String {
        dateFormatter(with: format).string(from: date)
    }
    
    static func date(from string: String, format: DateFormatter.Format) -> Date? {
        dateFormatter(with: format).date(from: string)
    }
}

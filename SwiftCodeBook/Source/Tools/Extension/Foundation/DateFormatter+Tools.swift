//
//  DateFormatter+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/8/16.
//

import Foundation
import os

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
    
    private static let dateFormatterMap = OSAllocatedUnfairLock(initialState: [DateFormatter.Format: DateFormatter]())
    
    private static func dateFormatter(with format: DateFormatter.Format) -> DateFormatter {
        dateFormatterMap.withLock { map in
            map[format] ?? {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = format.dateFormat
                dateFormatter.locale = format.locale
                dateFormatter.timeZone = format.timeZone
                map[format] = dateFormatter
                return dateFormatter
            }()
        }
    }
    
    static func string(from date: Date, format: DateFormatter.Format) -> String {
        dateFormatter(with: format).string(from: date)
    }
    
    static func date(from string: String, format: DateFormatter.Format) -> Date? {
        dateFormatter(with: format).date(from: string)
    }
}

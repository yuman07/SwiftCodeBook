//
//  DateFormatter+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/8/16.
//

import Foundation
import os

public extension DateFormatter {
    struct StyleKey: Hashable {
        public let dateFormat: String
        public let locale: Locale?
        public let timeZone: TimeZone?
        
        public init(dateFormat: String, locale: Locale? = nil, timeZone: TimeZone? = nil) {
            self.dateFormat = dateFormat
            self.locale = locale
            self.timeZone = timeZone
        }
    }
    
    private static let dateFormatterMap = OSAllocatedUnfairLock(initialState: [DateFormatter.StyleKey: DateFormatter]())
    
    private static func dateFormatter(with styleKey: DateFormatter.StyleKey) -> DateFormatter {
        dateFormatterMap.withLock { map in
            map[styleKey] ?? {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = styleKey.dateFormat
                if let timeZone = styleKey.locale {
                    dateFormatter.locale = styleKey.locale
                }
                if let timeZone = styleKey.timeZone {
                    dateFormatter.timeZone = styleKey.timeZone
                }
                map[styleKey] = dateFormatter
                return dateFormatter
            }()
        }
    }
    
    static func string(from date: Date, styleKey: DateFormatter.StyleKey) -> String {
        dateFormatter(with: styleKey).string(from: date)
    }
    
    static func date(from string: String, styleKey: DateFormatter.StyleKey) -> Date? {
        dateFormatter(with: styleKey).date(from: string)
    }
}

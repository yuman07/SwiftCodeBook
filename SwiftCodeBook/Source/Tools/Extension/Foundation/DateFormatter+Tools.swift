//
//  DateFormatter+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/8/16.
//

import Foundation

public extension DateFormatter {
    private static let lock = NSLock()
    private static var dateFormatterMap = [String: DateFormatter]()
    
    private static func dateFormatter(with dateFormat: String) -> DateFormatter {
        lock.withLock {
            dateFormatterMap[dateFormat] ?? {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = dateFormat
                dateFormatterMap[dateFormat] = dateFormatter
                return dateFormatter
            }()
        }
    }
    
    static func string(from date: Date, with dateFormat: String) -> String {
        dateFormatter(with: dateFormat).string(from: date)
    }
    
    static func date(from string: String, with dateFormat: String) -> Date? {
        dateFormatter(with: dateFormat).date(from: string)
    }
}

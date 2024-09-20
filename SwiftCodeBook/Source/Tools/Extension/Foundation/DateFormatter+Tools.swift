//
//  DateFormatter+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/8/16.
//

import Foundation
import os

public extension DateFormatter {
    private static let dateFormatterMap = OSAllocatedUnfairLock(initialState: [String: DateFormatter]())
    
    private static func dateFormatter(with dateFormat: String) -> DateFormatter {
        dateFormatterMap.withLock { map in
            map[dateFormat] ?? {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = dateFormat
                map[dateFormat] = dateFormatter
                return dateFormatter
            }()
        }
    }
    
    static func string(from date: Date, dateFormat: String) -> String {
        dateFormatter(with: dateFormat).string(from: date)
    }
    
    static func date(from string: String, dateFormat: String) -> Date? {
        dateFormatter(with: dateFormat).date(from: string)
    }
}

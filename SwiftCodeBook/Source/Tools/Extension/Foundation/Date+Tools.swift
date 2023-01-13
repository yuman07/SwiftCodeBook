//
//  Date+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/11.
//

import Foundation

public extension Date {
    private var calendar: Calendar {
        Calendar.autoupdatingCurrent
    }
    
    var century: Int {
        year / 100 + 1
    }
    
    var year: Int {
        calendar.component(.year, from: self)
    }
    
    var month: Int {
        calendar.component(.month, from: self)
    }
    
    /// The start of the week is Sunday and its value is 1
    var dayOfWeek: Int {
        calendar.component(.weekday, from: self)
    }
    
    var dayOfMonth: Int {
        calendar.component(.day, from: self)
    }
    
    var dayOfYear: Int {
        calendar.ordinality(of: .day, in: .year, for: self) ?? 1
    }
    
    var hour: Int {
        calendar.component(.hour, from: self)
    }
    
    var minute: Int {
        calendar.component(.minute, from: self)
    }
    
    var second: Int {
        calendar.component(.second, from: self)
    }
    
    var weekOfMonth: Int {
        calendar.component(.weekOfMonth, from: self)
    }
    
    var weekOfYear: Int {
        calendar.component(.weekOfYear, from: self)
    }
    
    var isInWeekend: Bool {
        let d = dayOfWeek
        return d == 1 || d == 6
    }
    
    var isInLeapYear: Bool {
        let y = year
        return y % 400 == 0 || (y % 4 == 0 && y % 100 != 0)
    }
    
    var daysInThisMonth: Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: return 31
        case 2: return isInLeapYear ? 29 : 28
        default: return 30
        }
    }
    
    var daysInThisYear: Int {
        isInLeapYear ? 366 : 365
    }
    
    var isToday: Bool {
        calendar.isDateInToday(self)
    }
    
    var isTomorrow: Bool {
        calendar.isDateInTomorrow(self)
    }
    
    var isYesterday: Bool {
        calendar.isDateInYesterday(self)
    }
    
    func days(from date: Date) -> Int {
        let from = calendar.ordinality(of: .day, in: .era, for: date) ?? 1
        let to = calendar.ordinality(of: .day, in: .era, for: self) ?? 1
        return to - from
    }
    
    func weeks(from date: Date) -> Int {
        let from = calendar.ordinality(of: .weekOfYear, in: .era, for: date) ?? 1
        let to = calendar.ordinality(of: .weekOfYear, in: .era, for: self) ?? 1
        return to - from
    }
    
    func months(from date: Date) -> Int {
        let from = calendar.ordinality(of: .month, in: .era, for: date) ?? 1
        let to = calendar.ordinality(of: .month, in: .era, for: self) ?? 1
        return to - from
    }
    
    func years(from date: Date) -> Int {
        let from = calendar.ordinality(of: .year, in: .era, for: date) ?? 1
        let to = calendar.ordinality(of: .year, in: .era, for: self) ?? 1
        return to - from
    }
    
    func isSameDay(with date: Date) -> Bool {
        days(from: date) == 0
    }
    
    func isSameWeek(with date: Date) -> Bool {
        weeks(from: date) == 0
    }
    
    func isSameMonth(with date: Date) -> Bool {
        months(from: date) == 0
    }
    
    func isSameYear(with date: Date) -> Bool {
        years(from: date) == 0
    }
    
    func adding(years: Int = 0, months: Int = 0, weeks: Int = 0, days: Int = 0, hours: Int = 0, minutes: Int = 0, seconds: Int = 0) -> Date? {
        var dateComponent = DateComponents()
        dateComponent.year = years
        dateComponent.month = months
        dateComponent.weekOfYear = weeks
        dateComponent.day = days
        dateComponent.hour = hours
        dateComponent.minute = minutes
        dateComponent.second = seconds
        return calendar.date(byAdding: dateComponent, to: self)
    }
}

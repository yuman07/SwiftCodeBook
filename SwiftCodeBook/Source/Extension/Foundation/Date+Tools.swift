//
//  Date+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/11.
//

import Foundation

extension Date {
    private var calendar: Calendar {
        Calendar.autoupdatingCurrent
    }
    
    var era: Int {
        calendar.component(.era, from: self)
    }
    
    var year: Int {
        calendar.component(.year, from: self)
    }
    
    var month: Int {
        calendar.component(.month, from: self)
    }
    
    // sunday is 1
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
    
    var isInLeapYear: Bool {
        let y = year
        return y % 400 == 0 || (y % 4 == 0 && y % 100 != 0)
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
    
    func seconds(from date: Date) -> Int {
        let from = calendar.ordinality(of: .second, in: .era, for: date) ?? 1
        let to = calendar.ordinality(of: .second, in: .era, for: self) ?? 1
        return to - from
    }
    
    func minutes(from date: Date) -> Int {
        let from = calendar.ordinality(of: .minute, in: .era, for: date) ?? 1
        let to = calendar.ordinality(of: .minute, in: .era, for: self) ?? 1
        return to - from
    }
    
    func hours(from date: Date) -> Int {
        let from = calendar.ordinality(of: .hour, in: .era, for: date) ?? 1
        let to = calendar.ordinality(of: .hour, in: .era, for: self) ?? 1
        return to - from
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
    
    func isSameSecond(with date: Date) -> Bool {
        seconds(from: date) == 0
    }
    
    func isSameMinute(with date: Date) -> Bool {
        minutes(from: date) == 0
    }
    
    func isSameHour(with date: Date) -> Bool {
        hours(from: date) == 0
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
}

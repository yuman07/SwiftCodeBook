//
//  Date+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/11.
//

import Foundation

public extension Date {
    private var calendar: Calendar {
        .current
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
    
    var startDateOfThisDay: Date {
        calendar.startOfDay(for: self)
    }
    
    var isInWeekend: Bool {
        calendar.isDateInWeekend(self)
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
    
    var startOfThisDay: Date {
        calendar.startOfDay(for: self)
    }
    
    func seconds(from date: Date) -> Int {
        calendar.dateComponents([.second], from: date, to: self).second ?? 0
    }
    
    func minutes(from date: Date) -> Int {
        calendar.dateComponents([.minute], from: date, to: self).minute ?? 0
    }
    
    func hours(from date: Date) -> Int {
        calendar.dateComponents([.hour], from: date, to: self).hour ?? 0
    }
    
    func days(from date: Date) -> Int {
        calendar.dateComponents([.day], from: date, to: self).day ?? 0
    }
    
    func weeks(from date: Date) -> Int {
        calendar.dateComponents([.weekOfYear], from: date, to: self).weekOfYear ?? 0
    }
    
    func months(from date: Date) -> Int {
        calendar.dateComponents([.month], from: date, to: self).month ?? 0
    }
    
    func years(from date: Date) -> Int {
        calendar.dateComponents([.year], from: date, to: self).year ?? 0
    }
    
    func isInSameDayAs(date: Date) -> Bool {
        calendar.isDate(self, inSameDayAs: date)
    }
    
    func isSame(with date: Date, toGranularity component: Calendar.Component) -> Bool {
        calendar.isDate(self, equalTo: date, toGranularity: component)
    }
    
    func addingBy(years: Int = 0, months: Int = 0, weeks: Int = 0, days: Int = 0, hours: Int = 0, minutes: Int = 0, seconds: Int = 0) -> Date? {
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

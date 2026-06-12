//
//  DateToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for Date+Tools.swift
//  Source under test:
//    SwiftCodeBook/Source/Tools/Extension/Foundation/Date+Tools.swift
//
//  Covers the Date extension helpers:
//    century, year, month, dayOfWeek, dayOfMonth, dayOfYear, hour, minute,
//    second, weekOfMonth, weekOfYear, isInWeekend, isInLeapYear, isToday,
//    isTomorrow, isYesterday, startOfThisDay, seconds/minutes/hours/days/
//    weeks/months/years(from:), isInSameDayAs(date:),
//    isSame(with:toGranularity:), addingBy(...).
//
//  NOTE: The source uses `Calendar.current` internally (depends on the
//  machine's timezone/locale). To stay deterministic regardless of the test
//  machine's configuration, dates are constructed THROUGH `Calendar.current`
//  itself so that the local-time component getters round-trip correctly. The
//  `.weekday` component value (Sun == 1) is locale-independent, so weekday
//  assertions are stable; weekend tests assert against the calendar's own
//  weekend rule to remain robust on non-Sat/Sun-weekend locales.
//

import Testing
import Foundation
@testable import SwiftCodeBook

@Suite struct DateToolsTests {

    // The same calendar the source uses. Building inputs with this guarantees
    // the component getters observe the values we set, on any machine.
    private static let cal = Calendar.current

    /// Build a Date from local-time components using `Calendar.current`.
    /// Returns nil if the components are not resolvable.
    private static func makeDate(
        year: Int,
        month: Int = 1,
        day: Int = 1,
        hour: Int = 0,
        minute: Int = 0,
        second: Int = 0
    ) -> Date? {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = day
        c.hour = hour
        c.minute = minute
        c.second = second
        return cal.date(from: c)
    }

    // MARK: - century

    @Test func centuryPositiveYears() throws {
        // 1..100 -> century 1, 101..200 -> century 2, etc.
        let d2022 = try #require(Self.makeDate(year: 2022, month: 11, day: 11))
        #expect(d2022.century == 21)

        let d2000 = try #require(Self.makeDate(year: 2000, month: 6, day: 15))
        #expect(d2000.century == 20)

        let d2001 = try #require(Self.makeDate(year: 2001, month: 1, day: 1))
        #expect(d2001.century == 21)

        let d100 = try #require(Self.makeDate(year: 100, month: 12, day: 31))
        #expect(d100.century == 1)

        let d101 = try #require(Self.makeDate(year: 101, month: 1, day: 1))
        #expect(d101.century == 2)

        let d1 = try #require(Self.makeDate(year: 1, month: 1, day: 1))
        #expect(d1.century == 1)

        // Exact century boundary on both sides of 1900/2000.
        let d1900 = try #require(Self.makeDate(year: 1900, month: 6, day: 1))
        #expect(d1900.century == 19) // 1801..1900 == 19th century

        let d1901 = try #require(Self.makeDate(year: 1901, month: 1, day: 1))
        #expect(d1901.century == 20)
    }

    // The proleptic Gregorian calendar in Foundation has no year 0; the
    // .year component reported can be a positive proleptic value, so we
    // assert the formula's behavior for the year value actually returned.
    @Test func centuryMatchesYearFormula() throws {
        let d = try #require(Self.makeDate(year: 1850, month: 5, day: 20))
        let y = d.year
        let expected: Int
        if y > 0 {
            expected = (y - 1) / 100 + 1
        } else {
            expected = (y + 1) / 100 - 1
        }
        #expect(d.century == expected)
    }

    // Sweep across several positive years, validating the source formula
    // against an independent reference computation for the reported year.
    @Test(arguments: [1, 99, 100, 101, 199, 200, 201, 1066, 1492, 1999, 2099, 2100])
    func centuryFormulaSweep(year: Int) throws {
        let d = try #require(Self.makeDate(year: year, month: 6, day: 15))
        let y = d.year
        // Independent reference: which 100-year block does year y land in?
        let expected = y > 0 ? (y - 1) / 100 + 1 : (y + 1) / 100 - 1
        #expect(d.century == expected)
        // Sanity: positive years yield positive centuries here.
        #expect(d.century >= 1)
    }

    // MARK: - year / month / day / time components round-trip

    @Test func yearMonthDayComponents() throws {
        let d = try #require(Self.makeDate(year: 2023, month: 7, day: 4, hour: 13, minute: 45, second: 30))
        #expect(d.year == 2023)
        #expect(d.month == 7)
        #expect(d.dayOfMonth == 4)
        #expect(d.hour == 13)
        #expect(d.minute == 45)
        #expect(d.second == 30)
    }

    @Test(arguments: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
    func monthBoundaries(month: Int) throws {
        let d = try #require(Self.makeDate(year: 2024, month: month, day: 15))
        #expect(d.month == month)
        #expect((1...12).contains(d.month))
    }

    @Test func timeMidnight() throws {
        let d = try #require(Self.makeDate(year: 2020, month: 1, day: 1, hour: 0, minute: 0, second: 0))
        #expect(d.hour == 0)
        #expect(d.minute == 0)
        #expect(d.second == 0)
    }

    @Test func timeEndOfDay() throws {
        let d = try #require(Self.makeDate(year: 2020, month: 1, day: 1, hour: 23, minute: 59, second: 59))
        #expect(d.hour == 23)
        #expect(d.minute == 59)
        #expect(d.second == 59)
    }

    // First and last day of a month round-trip correctly.
    @Test func dayOfMonthBoundaries() throws {
        let first = try #require(Self.makeDate(year: 2023, month: 3, day: 1))
        #expect(first.dayOfMonth == 1)

        // March has 31 days.
        let last = try #require(Self.makeDate(year: 2023, month: 3, day: 31))
        #expect(last.dayOfMonth == 31)

        // Non-leap February ends on the 28th.
        let febLast = try #require(Self.makeDate(year: 2023, month: 2, day: 28))
        #expect(febLast.dayOfMonth == 28)
        #expect(febLast.month == 2)
    }

    // MARK: - dayOfWeek (Sunday == 1)

    @Test func dayOfWeekKnownDate() throws {
        // 2022-11-11 is a Friday. weekday: Sun=1 ... Fri=6 ... Sat=7.
        let friday = try #require(Self.makeDate(year: 2022, month: 11, day: 11))
        #expect(friday.dayOfWeek == 6)

        // 2023-01-01 is a Sunday -> 1.
        let sunday = try #require(Self.makeDate(year: 2023, month: 1, day: 1))
        #expect(sunday.dayOfWeek == 1)

        // 2023-01-07 is a Saturday -> 7.
        let saturday = try #require(Self.makeDate(year: 2023, month: 1, day: 7))
        #expect(saturday.dayOfWeek == 7)
    }

    @Test func dayOfWeekAlwaysInRange() throws {
        for offset in 0..<14 {
            let d = try #require(Self.makeDate(year: 2024, month: 3, day: 1 + offset))
            #expect((1...7).contains(d.dayOfWeek))
        }
    }

    // Consecutive days increment the weekday by 1 (mod 7), wrapping 7 -> 1.
    @Test func dayOfWeekIncrementsAcrossConsecutiveDays() throws {
        // 2023-01-01 is a Sunday (1) through 2023-01-08 (next Sunday, 1).
        var previous: Int? = nil
        for day in 1...8 {
            let d = try #require(Self.makeDate(year: 2023, month: 1, day: day))
            let wd = d.dayOfWeek
            if let prev = previous {
                let expectedNext = prev == 7 ? 1 : prev + 1
                #expect(wd == expectedNext)
            }
            previous = wd
        }
    }

    // MARK: - dayOfYear

    @Test func dayOfYearFirstAndLast() throws {
        let jan1 = try #require(Self.makeDate(year: 2023, month: 1, day: 1))
        #expect(jan1.dayOfYear == 1)

        // 2023 is not a leap year -> 365 days.
        let dec31 = try #require(Self.makeDate(year: 2023, month: 12, day: 31))
        #expect(dec31.dayOfYear == 365)
    }

    @Test func dayOfYearLeapYearLastDay() throws {
        // 2024 is a leap year -> 366 days.
        let dec31Leap = try #require(Self.makeDate(year: 2024, month: 12, day: 31))
        #expect(dec31Leap.dayOfYear == 366)

        // Feb 29 exists in 2024 -> day 60.
        let feb29 = try #require(Self.makeDate(year: 2024, month: 2, day: 29))
        #expect(feb29.dayOfYear == 60)

        // March 1 of a non-leap year is day 60; of a leap year it is day 61.
        let mar1NonLeap = try #require(Self.makeDate(year: 2023, month: 3, day: 1))
        #expect(mar1NonLeap.dayOfYear == 60)
        let mar1Leap = try #require(Self.makeDate(year: 2024, month: 3, day: 1))
        #expect(mar1Leap.dayOfYear == 61)
    }

    @Test func dayOfYearIsMonotonicWithinYear() throws {
        var previous = 0
        // Sample the first of each month; ordinality must strictly increase.
        for month in 1...12 {
            let d = try #require(Self.makeDate(year: 2023, month: month, day: 1))
            let doy = d.dayOfYear
            #expect(doy > previous)
            previous = doy
        }
    }

    // MARK: - weekOfMonth / weekOfYear

    @Test func weekOfYearInRange() throws {
        let d = try #require(Self.makeDate(year: 2023, month: 6, day: 15))
        #expect((1...53).contains(d.weekOfYear))
    }

    @Test func weekOfMonthInRange() throws {
        let d = try #require(Self.makeDate(year: 2023, month: 6, day: 15))
        #expect((1...6).contains(d.weekOfMonth))
    }

    @Test func weekOfYearJanFirstIsEarly() throws {
        // Early January should yield a low week-of-year number.
        let jan2 = try #require(Self.makeDate(year: 2023, month: 1, day: 2))
        #expect(jan2.weekOfYear <= 2)
    }

    // weekOfMonth is locale-dependent (a month's first days may fall in
    // week 0 when minimumDaysInFirstWeek > 1). Assert the robust invariant
    // instead: the first day has the smallest weekOfMonth of the month, and
    // the value is non-decreasing as the days advance through the month.
    @Test func weekOfMonthIsNonDecreasingThroughMonth() throws {
        let firstOfMonth = try #require(Self.makeDate(year: 2023, month: 4, day: 1))
        let firstWeek = firstOfMonth.weekOfMonth
        #expect((0...1).contains(firstWeek))

        var previous = firstWeek
        for day in 1...30 { // April has 30 days
            let d = try #require(Self.makeDate(year: 2023, month: 4, day: day))
            let w = d.weekOfMonth
            #expect(w >= firstWeek)
            #expect(w >= previous)
            #expect((0...6).contains(w))
            previous = w
        }
    }

    // MARK: - isInWeekend

    // The source merely delegates to Calendar.isDateInWeekend; verify it keeps
    // that contract for both a known Saturday and a known weekday, and that the
    // result is internally consistent with the calendar over a full week.
    @Test func isInWeekendMatchesCalendarRule() throws {
        for offset in 0..<7 {
            let d = try #require(Self.makeDate(year: 2023, month: 1, day: 1 + offset, hour: 12))
            #expect(d.isInWeekend == Self.cal.isDateInWeekend(d))
        }
    }

    // A standard week contains a bounded number of weekend days (1...3) and the
    // weekend days are consistent across hours of the same day.
    @Test func isInWeekendBoundedAndStableWithinDay() throws {
        var weekendCount = 0
        for offset in 0..<7 {
            let noon = try #require(Self.makeDate(year: 2023, month: 1, day: 1 + offset, hour: 12))
            let earlyMorning = try #require(Self.makeDate(year: 2023, month: 1, day: 1 + offset, hour: 1))
            let lateNight = try #require(Self.makeDate(year: 2023, month: 1, day: 1 + offset, hour: 23))
            // Weekend status must be the same regardless of time of day.
            #expect(noon.isInWeekend == earlyMorning.isInWeekend)
            #expect(noon.isInWeekend == lateNight.isInWeekend)
            if noon.isInWeekend { weekendCount += 1 }
        }
        #expect((1...3).contains(weekendCount))
    }

    // MARK: - isInLeapYear

    @Test(arguments: [
        (2000, true),
        (1900, false),
        (2004, true),
        (2001, false),
        (2024, true),
        (2023, false),
        (2100, false),
        (2400, true),
        (1600, true),
        (1700, false),
        (4, true),
        (1, false),
    ])
    func leapYearRule(year: Int, expected: Bool) throws {
        let d = try #require(Self.makeDate(year: year, month: 6, day: 1))
        #expect(d.isInLeapYear == expected)
    }

    // Cross-check: a leap year must have a Feb 29 (day-of-year 366 on Dec 31);
    // a non-leap year must not (Dec 31 is day 365).
    @Test func isInLeapYearAgreesWithDayCount() throws {
        let leap = try #require(Self.makeDate(year: 2024, month: 12, day: 31))
        #expect(leap.isInLeapYear)
        #expect(leap.dayOfYear == 366)

        let nonLeap = try #require(Self.makeDate(year: 2023, month: 12, day: 31))
        #expect(!nonLeap.isInLeapYear)
        #expect(nonLeap.dayOfYear == 365)
    }

    // MARK: - isToday / isTomorrow / isYesterday

    @Test func isTodayForNow() {
        let now = Date()
        #expect(now.isToday)
        #expect(!now.isTomorrow)
        #expect(!now.isYesterday)
    }

    @Test func isTomorrowAndYesterday() throws {
        let now = Date()
        let tomorrow = try #require(Self.cal.date(byAdding: .day, value: 1, to: now))
        let yesterday = try #require(Self.cal.date(byAdding: .day, value: -1, to: now))

        #expect(tomorrow.isTomorrow)
        #expect(!tomorrow.isToday)
        #expect(!tomorrow.isYesterday)

        #expect(yesterday.isYesterday)
        #expect(!yesterday.isToday)
        #expect(!yesterday.isTomorrow)
    }

    @Test func farFutureIsNotTodayTomorrowYesterday() throws {
        let now = Date()
        let farFuture = try #require(Self.cal.date(byAdding: .day, value: 30, to: now))
        #expect(!farFuture.isToday)
        #expect(!farFuture.isTomorrow)
        #expect(!farFuture.isYesterday)

        let farPast = try #require(Self.cal.date(byAdding: .day, value: -30, to: now))
        #expect(!farPast.isToday)
        #expect(!farPast.isTomorrow)
        #expect(!farPast.isYesterday)
    }

    // Start-of-day and end-of-day of "today" both count as today.
    @Test func todayBoundariesAreToday() {
        let now = Date()
        let start = Self.cal.startOfDay(for: now)
        #expect(start.isToday)
        if let almostMidnight = Self.cal.date(byAdding: .second, value: 86_399, to: start) {
            #expect(almostMidnight.isToday)
        }
    }

    // MARK: - startOfThisDay

    @Test func startOfThisDayZeroesTime() throws {
        let d = try #require(Self.makeDate(year: 2023, month: 8, day: 20, hour: 17, minute: 33, second: 12))
        let start = d.startOfThisDay
        #expect(start.hour == 0)
        #expect(start.minute == 0)
        #expect(start.second == 0)
        // Same calendar day.
        #expect(start.isInSameDayAs(date: d))
        #expect(start == Self.cal.startOfDay(for: d))
        // The start of day is never after the original instant.
        #expect(start <= d)
    }

    @Test func startOfThisDayIsIdempotent() throws {
        let d = try #require(Self.makeDate(year: 2023, month: 8, day: 20, hour: 5))
        let once = d.startOfThisDay
        let twice = once.startOfThisDay
        #expect(once == twice)
    }

    // Applying startOfThisDay to an already-midnight date is a no-op.
    @Test func startOfThisDayOnMidnightIsNoOp() throws {
        let midnight = try #require(Self.makeDate(year: 2023, month: 8, day: 20, hour: 0, minute: 0, second: 0))
        #expect(midnight.startOfThisDay == midnight)
    }

    // MARK: - seconds/minutes/hours/days/weeks/months/years(from:)

    @Test func secondsFrom() throws {
        let base = try #require(Self.makeDate(year: 2023, month: 1, day: 1, hour: 0, minute: 0, second: 0))
        let later = try #require(Self.makeDate(year: 2023, month: 1, day: 1, hour: 0, minute: 0, second: 30))
        #expect(later.seconds(from: base) == 30)
        #expect(base.seconds(from: later) == -30)
        #expect(base.seconds(from: base) == 0)
    }

    @Test func minutesFrom() throws {
        let base = try #require(Self.makeDate(year: 2023, month: 1, day: 1, hour: 0, minute: 0))
        let later = try #require(Self.makeDate(year: 2023, month: 1, day: 1, hour: 0, minute: 45))
        #expect(later.minutes(from: base) == 45)
        #expect(base.minutes(from: later) == -45)
        #expect(base.minutes(from: base) == 0)
    }

    @Test func hoursFrom() throws {
        let base = try #require(Self.makeDate(year: 2023, month: 1, day: 1, hour: 0))
        let later = try #require(Self.makeDate(year: 2023, month: 1, day: 1, hour: 5))
        #expect(later.hours(from: base) == 5)
        #expect(base.hours(from: later) == -5)
        #expect(base.hours(from: base) == 0)
    }

    @Test func daysFrom() throws {
        let base = try #require(Self.makeDate(year: 2023, month: 1, day: 1))
        let later = try #require(Self.makeDate(year: 2023, month: 1, day: 11))
        #expect(later.days(from: base) == 10)
        #expect(base.days(from: later) == -10)
        #expect(base.days(from: base) == 0)
    }

    @Test func weeksFrom() throws {
        let base = try #require(Self.makeDate(year: 2023, month: 1, day: 1))
        let later = try #require(Self.makeDate(year: 2023, month: 1, day: 22)) // +21 days = 3 weeks
        #expect(later.weeks(from: base) == 3)
        #expect(base.weeks(from: later) == -3)
        #expect(base.weeks(from: base) == 0)
    }

    @Test func monthsFrom() throws {
        let base = try #require(Self.makeDate(year: 2023, month: 1, day: 1))
        let later = try #require(Self.makeDate(year: 2023, month: 7, day: 1))
        #expect(later.months(from: base) == 6)
        #expect(base.months(from: later) == -6)
        #expect(base.months(from: base) == 0)
    }

    @Test func yearsFrom() throws {
        let base = try #require(Self.makeDate(year: 2020, month: 1, day: 1))
        let later = try #require(Self.makeDate(year: 2025, month: 1, day: 1))
        #expect(later.years(from: base) == 5)
        #expect(base.years(from: later) == -5)
        #expect(base.years(from: base) == 0)
    }

    // Large but time-bounded: a long span should still compute correctly.
    @Test func daysFromLargeSpan() throws {
        let base = try #require(Self.makeDate(year: 1900, month: 1, day: 1))
        let later = try #require(Self.makeDate(year: 2000, month: 1, day: 1))
        // 100 Gregorian years from 1900-01-01 to 2000-01-01 == 36524 days
        // (24 leap years in that span: 1904..1996, and 2000 not yet reached).
        let days = later.days(from: base)
        #expect(days == 36524)
        #expect(base.days(from: later) == -days)
    }

    @Test func componentDiffsTruncateTowardZero() throws {
        // 29 days is 0 months and (truncated) 4 weeks.
        let base = try #require(Self.makeDate(year: 2023, month: 1, day: 1))
        let later = try #require(Self.makeDate(year: 2023, month: 1, day: 30)) // 29 days
        #expect(later.months(from: base) == 0)
        #expect(later.weeks(from: base) == 4)
        #expect(later.days(from: base) == 29)
    }

    // Just-under-one-unit spans truncate to 0; just-at-one-unit is 1.
    @Test func componentDiffsOffByOneAroundUnit() throws {
        let base = try #require(Self.makeDate(year: 2023, month: 1, day: 1, hour: 0, minute: 0, second: 0))
        let almostOneHour = try #require(Self.makeDate(year: 2023, month: 1, day: 1, hour: 0, minute: 59, second: 59))
        let exactlyOneHour = try #require(Self.makeDate(year: 2023, month: 1, day: 1, hour: 1, minute: 0, second: 0))
        #expect(almostOneHour.hours(from: base) == 0)
        #expect(almostOneHour.minutes(from: base) == 59)
        #expect(exactlyOneHour.hours(from: base) == 1)

        // Six days is 0 weeks; seven days is exactly 1 week.
        let sixDays = try #require(Self.makeDate(year: 2023, month: 1, day: 7))
        let sevenDays = try #require(Self.makeDate(year: 2023, month: 1, day: 8))
        #expect(sixDays.weeks(from: base) == 0)
        #expect(sevenDays.weeks(from: base) == 1)
    }

    // MARK: - isInSameDayAs(date:)

    @Test func isInSameDaySameDayDifferentTimes() throws {
        let morning = try #require(Self.makeDate(year: 2023, month: 5, day: 10, hour: 1))
        let evening = try #require(Self.makeDate(year: 2023, month: 5, day: 10, hour: 23))
        #expect(morning.isInSameDayAs(date: evening))
        #expect(evening.isInSameDayAs(date: morning))
    }

    @Test func isInSameDayDifferentDays() throws {
        let day1 = try #require(Self.makeDate(year: 2023, month: 5, day: 10, hour: 23, minute: 59))
        let day2 = try #require(Self.makeDate(year: 2023, month: 5, day: 11, hour: 0, minute: 1))
        #expect(!day1.isInSameDayAs(date: day2))
    }

    @Test func isInSameDaySameInstant() throws {
        let d = try #require(Self.makeDate(year: 2023, month: 5, day: 10, hour: 12))
        #expect(d.isInSameDayAs(date: d))
    }

    // Off-by-one across midnight and across a month boundary are different days.
    @Test func isInSameDayAcrossBoundaries() throws {
        let lastSecondOfDay = try #require(Self.makeDate(year: 2023, month: 1, day: 31, hour: 23, minute: 59, second: 59))
        let firstSecondNextDay = try #require(Self.makeDate(year: 2023, month: 2, day: 1, hour: 0, minute: 0, second: 0))
        #expect(!lastSecondOfDay.isInSameDayAs(date: firstSecondNextDay))

        // Same calendar date in different years is not the same day.
        let sameDateOtherYear = try #require(Self.makeDate(year: 2024, month: 1, day: 31, hour: 23, minute: 59, second: 59))
        #expect(!lastSecondOfDay.isInSameDayAs(date: sameDateOtherYear))
    }

    // MARK: - isSame(with:toGranularity:)

    @Test func isSameToYearGranularity() throws {
        let a = try #require(Self.makeDate(year: 2023, month: 1, day: 1))
        let b = try #require(Self.makeDate(year: 2023, month: 12, day: 31))
        #expect(a.isSame(with: b, toGranularity: .year))
        #expect(!a.isSame(with: b, toGranularity: .month))
        #expect(!a.isSame(with: b, toGranularity: .day))
    }

    @Test func isSameToMonthGranularity() throws {
        let a = try #require(Self.makeDate(year: 2023, month: 6, day: 1))
        let b = try #require(Self.makeDate(year: 2023, month: 6, day: 30))
        #expect(a.isSame(with: b, toGranularity: .month))
        #expect(a.isSame(with: b, toGranularity: .year))
        #expect(!a.isSame(with: b, toGranularity: .day))
    }

    @Test func isSameToDayGranularity() throws {
        let a = try #require(Self.makeDate(year: 2023, month: 6, day: 15, hour: 1))
        let b = try #require(Self.makeDate(year: 2023, month: 6, day: 15, hour: 23))
        #expect(a.isSame(with: b, toGranularity: .day))
        // Different hours -> not same at hour granularity.
        #expect(!a.isSame(with: b, toGranularity: .hour))
    }

    @Test func isSameToHourGranularity() throws {
        let a = try #require(Self.makeDate(year: 2023, month: 6, day: 15, hour: 10, minute: 0))
        let b = try #require(Self.makeDate(year: 2023, month: 6, day: 15, hour: 10, minute: 59))
        #expect(a.isSame(with: b, toGranularity: .hour))
        #expect(a.isSame(with: b, toGranularity: .day))
        #expect(!a.isSame(with: b, toGranularity: .minute))
    }

    @Test func isSameDifferentYears() throws {
        let a = try #require(Self.makeDate(year: 2022, month: 6, day: 15))
        let b = try #require(Self.makeDate(year: 2023, month: 6, day: 15))
        #expect(!a.isSame(with: b, toGranularity: .year))
        #expect(!a.isSame(with: b, toGranularity: .month))
        #expect(!a.isSame(with: b, toGranularity: .day))
    }

    @Test func isSameWithSelfIsAlwaysTrue() throws {
        let d = try #require(Self.makeDate(year: 2023, month: 6, day: 15, hour: 10, minute: 30, second: 45))
        for granularity in [Calendar.Component.era, .year, .month, .day, .hour, .minute, .second] {
            #expect(d.isSame(with: d, toGranularity: granularity))
        }
    }

    // MARK: - addingBy(...)

    @Test func addingByDefaultsIsNoChange() throws {
        let d = try #require(Self.makeDate(year: 2023, month: 6, day: 15, hour: 12, minute: 30, second: 45))
        let result = try #require(d.addingBy())
        #expect(result == d)
    }

    @Test func addingByZerosIsNoChange() throws {
        let d = try #require(Self.makeDate(year: 2023, month: 6, day: 15, hour: 12, minute: 30, second: 45))
        let result = try #require(d.addingBy(years: 0, months: 0, weeks: 0, days: 0, hours: 0, minutes: 0, seconds: 0))
        #expect(result == d)
    }

    @Test func addingByYears() throws {
        let d = try #require(Self.makeDate(year: 2020, month: 6, day: 15))
        let result = try #require(d.addingBy(years: 3))
        #expect(result.year == 2023)
        #expect(result.month == 6)
        #expect(result.dayOfMonth == 15)
    }

    @Test func addingByMonthsRollsOverYear() throws {
        let d = try #require(Self.makeDate(year: 2023, month: 11, day: 1))
        let result = try #require(d.addingBy(months: 3)) // -> Feb 2024
        #expect(result.year == 2024)
        #expect(result.month == 2)
    }

    @Test func addingByMonthsRollsBackOverYear() throws {
        let d = try #require(Self.makeDate(year: 2023, month: 1, day: 15))
        let result = try #require(d.addingBy(months: -2)) // -> Nov 2022
        #expect(result.year == 2022)
        #expect(result.month == 11)
        #expect(result.dayOfMonth == 15)
    }

    @Test func addingByDays() throws {
        let d = try #require(Self.makeDate(year: 2023, month: 1, day: 30))
        let result = try #require(d.addingBy(days: 5)) // -> Feb 4
        #expect(result.month == 2)
        #expect(result.dayOfMonth == 4)
    }

    @Test func addingByWeeks() throws {
        let d = try #require(Self.makeDate(year: 2023, month: 1, day: 1))
        let result = try #require(d.addingBy(weeks: 2))
        #expect(result.days(from: d) == 14)
    }

    @Test func addingByHoursMinutesSeconds() throws {
        let d = try #require(Self.makeDate(year: 2023, month: 1, day: 1, hour: 10, minute: 0, second: 0))
        let result = try #require(d.addingBy(hours: 2, minutes: 30, seconds: 15))
        #expect(result.hour == 12)
        #expect(result.minute == 30)
        #expect(result.second == 15)
    }

    @Test func addingByNegativeValues() throws {
        let d = try #require(Self.makeDate(year: 2023, month: 3, day: 15))
        let result = try #require(d.addingBy(years: -1, months: -2, days: -10))
        #expect(result.year == 2022)
        #expect(result.month == 1)
        #expect(result.dayOfMonth == 5)
    }

    @Test func addingByCombinedComponents() throws {
        let d = try #require(Self.makeDate(year: 2023, month: 1, day: 1, hour: 0, minute: 0, second: 0))
        let result = try #require(d.addingBy(years: 1, months: 1, weeks: 1, days: 1, hours: 1, minutes: 1, seconds: 1))
        // year 2023 + 1 = 2024; month +1 -> Feb; week +1 -> +7 days; day +1.
        #expect(result.year == 2024)
        #expect(result.month == 2)
        // Day: Feb 1 + 7 (week) + 1 (day) = Feb 9.
        #expect(result.dayOfMonth == 9)
        #expect(result.hour == 1)
        #expect(result.minute == 1)
        #expect(result.second == 1)
    }

    @Test func addingByRoundTripInverse() throws {
        let d = try #require(Self.makeDate(year: 2023, month: 6, day: 15, hour: 8, minute: 20, second: 5))
        let forward = try #require(d.addingBy(days: 100, hours: 5, minutes: 30))
        let back = try #require(forward.addingBy(days: -100, hours: -5, minutes: -30))
        #expect(back == d)
    }

    @Test func addingByLargeValue() throws {
        let d = try #require(Self.makeDate(year: 2000, month: 1, day: 1))
        let result = try #require(d.addingBy(years: 100))
        #expect(result.year == 2100)
    }

    @Test func addingByLeapDayClamps() throws {
        // Feb 29 2024 + 1 year -> 2025 has no Feb 29; calendar clamps to Feb 28.
        let leapDay = try #require(Self.makeDate(year: 2024, month: 2, day: 29))
        let result = try #require(leapDay.addingBy(years: 1))
        #expect(result.year == 2025)
        #expect(result.month == 2)
        #expect(result.dayOfMonth == 28)
    }

    // Adding one month to Jan 31 clamps to the last day of February (28 or 29).
    @Test func addingByMonthClampsEndOfMonth() throws {
        let jan31NonLeap = try #require(Self.makeDate(year: 2023, month: 1, day: 31))
        let resultNonLeap = try #require(jan31NonLeap.addingBy(months: 1))
        #expect(resultNonLeap.month == 2)
        #expect(resultNonLeap.dayOfMonth == 28)

        let jan31Leap = try #require(Self.makeDate(year: 2024, month: 1, day: 31))
        let resultLeap = try #require(jan31Leap.addingBy(months: 1))
        #expect(resultLeap.month == 2)
        #expect(resultLeap.dayOfMonth == 29)
    }

    // MARK: - Concurrency: the getters are pure reads; hammer concurrently.

    @Test func concurrentReadsAreConsistent() async throws {
        let d = try #require(Self.makeDate(year: 2023, month: 7, day: 4, hour: 13, minute: 45, second: 30))
        let expectedYear = d.year
        let expectedMonth = d.month
        let expectedDay = d.dayOfMonth
        let expectedCentury = d.century

        let results: [Snapshot] = await withTaskGroup(of: Snapshot.self) { group in
            for _ in 0..<500 {
                group.addTask {
                    Snapshot(year: d.year, month: d.month, day: d.dayOfMonth, century: d.century)
                }
            }
            var collected: [Snapshot] = []
            for await r in group {
                collected.append(r)
            }
            return collected
        }

        #expect(results.count == 500)
        for r in results {
            #expect(r.year == expectedYear)
            #expect(r.month == expectedMonth)
            #expect(r.day == expectedDay)
            #expect(r.century == expectedCentury)
        }
    }

    @Test func concurrentAddingByIsConsistent() async throws {
        let d = try #require(Self.makeDate(year: 2023, month: 1, day: 1, hour: 0, minute: 0, second: 0))
        let expected = try #require(d.addingBy(days: 10, hours: 3))

        let allMatch = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<300 {
                group.addTask {
                    guard let r = d.addingBy(days: 10, hours: 3) else { return false }
                    return r == expected
                }
            }
            var ok = true
            for await match in group {
                ok = ok && match
            }
            return ok
        }
        #expect(allMatch)
    }

    // A Sendable snapshot for shuttling getter results out of child tasks.
    private struct Snapshot: Sendable {
        let year: Int
        let month: Int
        let day: Int
        let century: Int
    }
}

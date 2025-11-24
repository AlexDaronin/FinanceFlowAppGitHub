//
//  DateRangeHelper.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import Foundation

struct DateRangeHelper {
    /// Calculates the start date of the current financial period based on startDay
    /// Example: If startDay is 15 and today is Dec 20, returns Dec 15
    ///          If startDay is 15 and today is Dec 10, returns Nov 15
    static func periodStart(for startDay: Int, referenceDate: Date = Date()) -> Date {
        let calendar = Calendar.current
        let todayDay = calendar.component(.day, from: referenceDate)
        
        // Determine which month to use as base
        let base = todayDay < startDay
            ? calendar.date(byAdding: .month, value: -1, to: referenceDate) ?? referenceDate
            : referenceDate
        
        // Set the day to startDay
        var components = calendar.dateComponents([.year, .month], from: base)
        components.day = startDay
        return calendar.date(from: components) ?? referenceDate
    }
    
    /// Calculates the end date of the current financial period (exclusive)
    /// This is one month after periodStart
    static func periodEnd(for startDay: Int, referenceDate: Date = Date()) -> Date {
        let start = periodStart(for: startDay, referenceDate: referenceDate)
        return Calendar.current.date(byAdding: .month, value: 1, to: start) ?? start
    }
    
    /// Returns a tuple of (start, end) dates for the current financial period
    static func currentPeriod(for startDay: Int, referenceDate: Date = Date()) -> (start: Date, end: Date) {
        let start = periodStart(for: startDay, referenceDate: referenceDate)
        let end = periodEnd(for: startDay, referenceDate: referenceDate)
        return (start, end)
    }
    
    /// Checks if a date falls within the current financial period
    static func isInCurrentPeriod(_ date: Date, startDay: Int, referenceDate: Date = Date()) -> Bool {
        let period = currentPeriod(for: startDay, referenceDate: referenceDate)
        return date >= period.start && date < period.end
    }
    
    /// Gets the period for a specific offset (0 = current, -1 = previous, 1 = next, etc.)
    static func period(for startDay: Int, offset: Int, referenceDate: Date = Date()) -> (start: Date, end: Date) {
        let baseDate = Calendar.current.date(byAdding: .month, value: offset, to: referenceDate) ?? referenceDate
        return currentPeriod(for: startDay, referenceDate: baseDate)
    }
}


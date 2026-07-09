//
//  ScanStreak.swift
//  ClearMaxx — pure logic for the "N Day Streak" badge: consecutive calendar
//  days (ending today or yesterday) with at least one scan.
//

import Foundation

enum ScanStreak {
    /// `scanDates` need not be sorted or deduplicated. A streak survives a day
    /// still in progress — if there's no scan yet today but there was one
    /// yesterday, the streak counts back from yesterday rather than resetting.
    static func current(scanDates: [Date], calendar: Calendar = .current, today: Date = Date()) -> Int {
        let days = Set(scanDates.map { calendar.startOfDay(for: $0) })
        let startOfToday = calendar.startOfDay(for: today)
        guard var cursor = days.contains(startOfToday)
            ? startOfToday
            : calendar.date(byAdding: .day, value: -1, to: startOfToday)
        else { return 0 }

        guard days.contains(cursor) else { return 0 }
        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let prior = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prior
        }
        return streak
    }
}

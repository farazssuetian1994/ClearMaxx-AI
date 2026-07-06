//
//  ScanHistory.swift
//  ClearMaxx — SwiftData persistence: one record per scan, one checklist per day.
//

import Foundation
import SwiftData

@Model
final class ScanRecord {
    var date: Date
    var clearScore: Int
    var confidence: Int
    var skinType: String
    var summary: String
    var metrics: [PersistedMetric]
    var photoFileName: String

    init(date: Date, clearScore: Int, confidence: Int, skinType: String,
         summary: String, metrics: [PersistedMetric], photoFileName: String) {
        self.date = date
        self.clearScore = clearScore
        self.confidence = confidence
        self.skinType = skinType
        self.summary = summary
        self.metrics = metrics
        self.photoFileName = photoFileName
    }
}

@Model
final class DailyRoutineChecklist {
    var day: Date
    var steps: [PersistedRoutineStep]

    init(day: Date, steps: [PersistedRoutineStep]) {
        self.day = day
        self.steps = steps
    }
}

struct PersistedRoutineStep: Codable, Hashable {
    var time: String       // "AM" or "PM"
    var category: String
    var title: String
    var detail: String
    var tags: [String]
    var done: Bool
}

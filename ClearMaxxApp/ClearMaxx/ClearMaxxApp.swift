//
//  ClearMaxxApp.swift
//  ClearMaxx — AI Skin & Face Scanner
//

import SwiftUI
import SwiftData

@main
struct ClearMaxxApp: App {
    @StateObject private var state = AppState()

    init() {
        startHotReload()
        PurchaseService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .tint(CMColor.violet)
                .preferredColorScheme(.light)
        }
        .modelContainer(for: [ScanRecord.self, DailyRoutineChecklist.self, ProgressReportCache.self])
    }
}

//
//  ClearMaxxApp.swift
//  ClearMaxx — AI Skin & Face Scanner
//

import SwiftUI
import SwiftData

@main
struct ClearMaxxApp: App {
    @StateObject private var state = AppState()
    @StateObject private var locale = CMLocale.shared

    init() {
        startHotReload()
        PurchaseService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .environmentObject(locale)
                // Strings are read through `L(...)` rather than SwiftUI's own
                // localization, so nothing in the tree observes the catalog on
                // its own. Re-keying the root on the language code rebuilds
                // every view — the one place that cost is paid, and only when
                // the user actually switches language.
                .id(locale.language)
                .environment(\.locale, locale.foundationLocale)
                .environment(\.layoutDirection, locale.layoutDirection)
                .tint(CMColor.violet)
                .preferredColorScheme(.light)
        }
        .modelContainer(for: [ScanRecord.self, DailyRoutineChecklist.self, ProgressReportCache.self])
    }
}

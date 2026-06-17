//
//  ClearMaxxApp.swift
//  ClearMaxx — AI Skin & Face Scanner
//

import SwiftUI

@main
struct ClearMaxxApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .tint(CMColor.violet)
        }
    }
}

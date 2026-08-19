//
//  MainTabView.swift
//  ClearMaxx — custom glass bottom tab bar (Scan · Progress · Routine · Profile)
//

import SwiftUI

enum CMTab: Int, CaseIterable {
    case scan, progress, routine, history, profile
    var title: String {
        switch self {
        case .scan: return L("nav.scan")
        case .progress: return L("nav.progress")
        case .routine: return L("nav.routine")
        case .history: return L("nav.history")
        case .profile: return L("nav.profile")
        }
    }
    var icon: String {
        switch self {
        case .scan: return "camera.viewfinder"
        case .progress: return "chart.line.uptrend.xyaxis"
        case .routine: return "leaf.fill"
        case .history: return "clock.arrow.circlepath"
        case .profile: return "person.crop.circle"
        }
    }
}

struct MainTabView: View {
    @ObserveInjection var inject
    @EnvironmentObject var state: AppState
    @State private var tab: CMTab = .scan

    var body: some View {
        Group {
            switch tab {
            case .scan:     CameraScanView()
            case .progress: SkinProgressView()
            case .routine:  DailyRoutineView()
            case .history:  NavigationStack { ScanHistoryView() }
            case .profile:  ProfileView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The tab bar is a safe-area INSET rather than a ZStack overlay: SwiftUI
        // then subtracts its height from every screen's safe area automatically,
        // so scroll content stops above it instead of sliding underneath. This is
        // what lets the screens drop their hand-tuned `.padding(.bottom, 100)`
        // clearances, which never accounted for the home indicator either.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !state.hideTabBar {
                // The Scan tab is a full-bleed black camera view; a white glass bar
                // reads as a bright slab against it, so the bar goes smoked-dark there
                // and stays light glass over the dewy screens.
                CMTabBar(selected: $tab, style: tab == .scan ? .dark : .light)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: state.hideTabBar)
        .animation(.easeInOut(duration: 0.28), value: tab)
        .ignoresSafeArea(.keyboard)
    }
}

struct CMTabBar: View {
    @Binding var selected: CMTab
    var style: Style = .light

    /// How the bar tints itself against the screen behind it.
    enum Style {
        case light   // over the dewy lavender-white screens
        case dark    // over the full-bleed black camera preview

        var wash: Color { self == .dark ? .black.opacity(0.82) : .white.opacity(0.7) }
        var hairline: Color { self == .dark ? .white.opacity(0.18) : .white.opacity(0.6) }
        /// Inactive items need far more contrast on dark than the old 0.6 ink gave.
        var inactive: Color { self == .dark ? .white.opacity(0.7) : CMColor.inkSoft.opacity(0.75) }
        var active: Color { self == .dark ? CMColor.primary : CMColor.violetDeep }
        var activePill: Color { self == .dark ? CMColor.primary.opacity(0.26) : CMColor.violet.opacity(0.12) }

        /// The app is pinned to `.preferredColorScheme(.light)`, which makes system
        /// materials render as a pale slab. Rendering the dark bar in the dark scheme
        /// is what lets `.ultraThinMaterial` blur to smoked charcoal instead of gray.
        var scheme: ColorScheme { self == .dark ? .dark : .light }
    }

    var body: some View {
        HStack {
            ForEach(CMTab.allCases, id: \.self) { t in
                Button { selected = t } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if selected == t {
                                Circle().fill(style.activePill).frame(width: 40, height: 40)
                            }
                            Image(systemName: t.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(selected == t ? style.active : style.inactive)
                        }
                        Text(t.title)
                            .font(CMFont.inter(10, selected == t ? .semibold : .medium))
                            .foregroundStyle(selected == t ? style.active : style.inactive)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial)
        .background(style.wash)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(style.hairline, lineWidth: 1))
        .environment(\.colorScheme, style.scheme)
        .shadow(color: .black.opacity(style == .dark ? 0.4 : 0.10), radius: 18, x: 0, y: 10)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

#Preview {
    MainTabView().environmentObject(AppState())
}

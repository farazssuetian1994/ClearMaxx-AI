//
//  MainTabView.swift
//  ClearMaxx — custom glass bottom tab bar (Scan · Progress · Routine · Diary · Profile)
//

import SwiftUI

enum CMTab: Int, CaseIterable {
    case scan, progress, routine, diary, profile
    var title: String {
        switch self {
        case .scan: return "Scan"
        case .progress: return "Progress"
        case .routine: return "Routine"
        case .diary: return "Diary"
        case .profile: return "Profile"
        }
    }
    var icon: String {
        switch self {
        case .scan: return "camera.viewfinder"
        case .progress: return "chart.line.uptrend.xyaxis"
        case .routine: return "leaf.fill"
        case .diary: return "book.closed.fill"
        case .profile: return "person.crop.circle"
        }
    }
}

struct MainTabView: View {
    @State private var tab: CMTab = .scan

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .scan:     CameraScanView()
                case .progress: SkinProgressView()
                case .routine:  DailyRoutineView()
                case .diary:    SkinDiaryView()
                case .profile:  ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            CMTabBar(selected: $tab)
        }
        .ignoresSafeArea(.keyboard)
    }
}

struct CMTabBar: View {
    @Binding var selected: CMTab

    var body: some View {
        HStack {
            ForEach(CMTab.allCases, id: \.self) { t in
                Button { selected = t } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if selected == t {
                                Circle().fill(CMColor.violet.opacity(0.12)).frame(width: 40, height: 40)
                            }
                            Image(systemName: t.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(selected == t ? CMColor.violetDeep : CMColor.inkSoft.opacity(0.6))
                        }
                        Text(t.title)
                            .font(CMFont.inter(10, .medium))
                            .foregroundStyle(selected == t ? CMColor.violetDeep : CMColor.inkSoft.opacity(0.6))
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
        .background(.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.6), lineWidth: 1))
        .bloomShadow()
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }
}

#Preview {
    MainTabView().environmentObject(AppState())
}

//
//  ProfileView.swift
//  ClearMaxx — Profile tab. Avatar, premium badge, stats, settings list.
//

import SwiftUI

struct ProfileView: View {
    @ObserveInjection var inject
    @EnvironmentObject var state: AppState
    @State private var showPaywall = false

    private let settings: [(String, String)] = [
        ("bell.fill", "Reminders"),
        ("face.smiling", "Skin Profile"),
        ("person.crop.circle.badge.plus", "Account"),
        ("slider.horizontal.3", "Notifications"),
        ("questionmark.circle", "Support")
    ]

    var body: some View {
        DewyBackground {
            ScrollView {
                VStack(spacing: 18) {
                    CMTopBar(showBack: true)

                    // Avatar
                    ZStack(alignment: .bottom) {
                        Circle().fill(CMGradient.auraDiagonal).frame(width: 120, height: 120)
                            .overlay(Image(systemName: "person.fill").font(.system(size: 54)).foregroundStyle(.white.opacity(0.9)))
                            .overlay(Circle().stroke(CMGradient.aura, lineWidth: 3))
                        Text("PREMIUM").font(CMFont.inter(10, .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 5)
                            .background(CMGradient.aura, in: Capsule())
                            .offset(y: 12)
                    }
                    .padding(.top, 8)

                    VStack(spacing: 2) {
                        Text("Elena Vance").font(CMFont.headlineLg).foregroundStyle(CMColor.ink)
                        Text("elena.v@example.com").font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                    }

                    HStack(spacing: 14) {
                        statCard(title: "Skin Score", value: "\(state.clearScore)", suffix: "/100", tint: CMColor.violetDeep)
                        statCard(title: "Scan Streak", value: "\(state.scanStreak)", suffix: "days", tint: CMColor.coralDeep)
                    }

                    if !state.isPremium {
                        Button { showPaywall = true } label: {
                            HStack {
                                Image(systemName: "crown.fill")
                                Text("Upgrade to ClearMaxx Plus").font(CMFont.labelMd)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .foregroundStyle(.white).padding(16)
                            .background(CMGradient.aura, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }.buttonStyle(.plain)
                    }

                    HStack { CategoryLabel(text: "Settings", color: CMColor.inkSoft); Spacer() }.padding(.top, 4)

                    GlassCard {
                        VStack(spacing: 0) {
                            ForEach(Array(settings.enumerated()), id: \.offset) { i, item in
                                HStack(spacing: 14) {
                                    Image(systemName: item.0).foregroundStyle(CMColor.violet)
                                        .frame(width: 40, height: 40)
                                        .background(CMColor.violet.opacity(0.1), in: Circle())
                                    Text(item.1).font(CMFont.bodyLg).foregroundStyle(CMColor.ink)
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(CMColor.outline)
                                }
                                .padding(.vertical, 10)
                                if i < settings.count - 1 { Divider().opacity(0.4) }
                            }
                        }
                    }

                    Button { } label: {
                        Text("Log Out").font(CMFont.title).foregroundStyle(CMColor.error)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(CMColor.error.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }.buttonStyle(.plain)

                    Text("ClearMaxx v1.0.0").font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft.opacity(0.6))
                        .padding(.bottom, 100)
                }
                .padding(.horizontal, 24)
            }
        }
        .sheet(isPresented: $showPaywall) { GoPremiumView() }
    }

    private func statCard(title: String, value: String, suffix: String, tint: Color) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(CMFont.labelMd).foregroundStyle(tint)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value).font(CMFont.inter(28, .heavy)).foregroundStyle(CMColor.ink)
                    Text(suffix).font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft)
                }
            }
        }
    }
}

#Preview { ProfileView().environmentObject(AppState()) }

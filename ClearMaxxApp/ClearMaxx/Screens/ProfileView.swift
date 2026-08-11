//
//  ProfileView.swift
//  ClearMaxx — Profile tab. Avatar, premium badge, stats, settings list.
//

import SwiftUI
import PhotosUI

private enum SettingsAction {
    case about
    case restorePurchases
    case url(URL)
    case mail(String)
}

private struct SettingsItem {
    let icon: String
    let title: String
    let action: SettingsAction
}

struct ProfileView: View {
    @ObserveInjection var inject
    @EnvironmentObject var state: AppState
    @Environment(\.openURL) private var openURL
    @State private var showPaywall = false
    @State private var showAbout = false
    @State private var isRestoring = false
    @State private var restoreMessage: String?
    @State private var avatarImage: UIImage?
    @State private var avatarPickerItem: PhotosPickerItem?

    private let settings: [SettingsItem] = [
        SettingsItem(icon: "info.circle", title: "About", action: .about),
        SettingsItem(icon: "arrow.clockwise", title: "Restore Purchases", action: .restorePurchases),
        SettingsItem(icon: "hand.raised", title: "Privacy Policy",
                     action: .url(URL(string: "https://clearmaxxai.blogspot.com/p/privacy-policy.html")!)),
        SettingsItem(icon: "doc.text", title: "Terms of Use",
                     action: .url(URL(string: "https://clearmaxxai.blogspot.com/p/terms-of-service.html")!)),
        SettingsItem(icon: "questionmark.circle", title: "Support", action: .mail("support@clearmaxxai.com"))
    ]

    var body: some View {
        DewyBackground {
            ScrollView {
                VStack(spacing: 18) {
                    CMTopBar(showBack: true)

                    // Avatar — tap to pick a photo; PREMIUM badge only shows when actually premium.
                    PhotosPicker(selection: $avatarPickerItem, matching: .images) {
                        ZStack(alignment: .bottom) {
                            Group {
                                if let avatarImage {
                                    Image(uiImage: avatarImage).resizable().scaledToFill()
                                } else {
                                    Circle().fill(CMGradient.auraDiagonal)
                                        .overlay(Image(systemName: "person.fill").font(.system(size: 54)).foregroundStyle(.white.opacity(0.9)))
                                }
                            }
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(CMGradient.aura, lineWidth: 3))
                            .overlay(alignment: .topTrailing) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(CMGradient.aura, in: Circle())
                                    .overlay(Circle().stroke(.white, lineWidth: 2))
                                    .offset(x: 2, y: 2)
                            }
                            if state.isPremium {
                                Text("PREMIUM").font(CMFont.inter(10, .bold)).foregroundStyle(.white)
                                    .padding(.horizontal, 14).padding(.vertical, 5)
                                    .background(CMGradient.aura, in: Capsule())
                                    .offset(y: 12)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Profile photo. Tap to change.")
                    .padding(.top, 8)

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
                                Button { handle(item.action) } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: item.icon).foregroundStyle(CMColor.violet)
                                            .frame(width: 40, height: 40)
                                            .background(CMColor.violet.opacity(0.1), in: Circle())
                                        Text(item.title).font(CMFont.bodyLg).foregroundStyle(CMColor.ink)
                                        Spacer()
                                        if isRestoring, case .restorePurchases = item.action {
                                            ProgressView()
                                        } else {
                                            Image(systemName: "chevron.right").foregroundStyle(CMColor.outline)
                                        }
                                    }
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .disabled(isRestoring)
                                if i < settings.count - 1 { Divider().opacity(0.4) }
                            }
                        }
                    }

                    Text(appVersionString).font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft.opacity(0.6))
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 24)
            }
        }
        .sheet(isPresented: $showPaywall) { GoPremiumView() }
        .sheet(isPresented: $showAbout) { AboutView() }
        .alert("Restore Purchases", isPresented: .constant(restoreMessage != nil), presenting: restoreMessage) { _ in
            Button("OK") { restoreMessage = nil }
        } message: { Text($0) }
        .onAppear {
            if avatarImage == nil { avatarImage = ProfileAvatarStore.load() }
        }
        .onChange(of: avatarPickerItem) { _, item in
            guard let item else { return }
            Task {
                defer { avatarPickerItem = nil }
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                avatarImage = image
                ProfileAvatarStore.save(image)
            }
        }
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "ClearMaxx v\(version)"
    }

    private func handle(_ action: SettingsAction) {
        switch action {
        case .about:
            showAbout = true
        case .url(let url):
            openURL(url)
        case .mail(let address):
            openURL(URL(string: "mailto:\(address)")!)
        case .restorePurchases:
            restore()
        }
    }

    private func restore() {
        isRestoring = true
        Task {
            do {
                let entitled = try await PurchaseService.shared.restorePurchases()
                state.isPremium = entitled
                restoreMessage = entitled ? "Your ClearMaxx Plus subscription was restored." : "No active subscription found for this Apple ID."
            } catch {
                restoreMessage = error.localizedDescription
            }
            isRestoring = false
        }
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

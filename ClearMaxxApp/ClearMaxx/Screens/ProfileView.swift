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
        SettingsItem(icon: "lock.shield", title: "Privacy Policy",
                     action: .url(URL(string: "https://clearmaxxai.blogspot.com/p/privacy-policy.html")!)),
        SettingsItem(icon: "doc.text", title: "Terms of Use",
                     action: .url(URL(string: "https://clearmaxxai.blogspot.com/p/terms-of-service.html")!)),
        SettingsItem(icon: "questionmark.circle", title: "Help & Support", action: .mail("support@clearmaxxai.com"))
    ]

    /// Honest tiering of the real ClearScore — not decorative, just a label for the number.
    private var skinScoreTag: (text: String, tint: Color) {
        switch state.clearScore {
        case ..<40: return ("Needs attention", CMColor.error)
        case 40..<70: return ("Needs improvement", CMColor.coralDeep)
        case 70..<85: return ("Good", CMColor.success)
        default: return ("Excellent", CMColor.success)
        }
    }

    var body: some View {
        DewyBackground {
            ScrollView {
                VStack(spacing: 18) {
                    CMTopBar(showBack: true, trailing: AnyView(
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(CMColor.ink)
                            .frame(width: 36, height: 36)
                            .background(CMColor.cardSoft, in: Circle())
                    ))

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

                    VStack(spacing: 4) {
                        Text("Hi there!").font(CMFont.headlineMd).foregroundStyle(CMColor.ink)
                        Text("Track your skin. See real progress.").font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                    }

                    statCard(icon: "chart.line.uptrend.xyaxis", title: "Skin Score",
                             value: "\(state.clearScore)", suffix: "/100",
                             tint: CMColor.violetDeep, tag: skinScoreTag)

                    if !state.isPremium {
                        Button { showPaywall = true } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle().fill(.white.opacity(0.22)).frame(width: 40, height: 40)
                                    Image(systemName: "crown.fill").foregroundStyle(.white)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Upgrade to ClearMaxx Plus").font(CMFont.labelMd).fontWeight(.semibold)
                                    Text("Unlock advanced insights and features.")
                                        .font(CMFont.labelSm).opacity(0.9)
                                }
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

    private func statCard(icon: String, title: String, value: String, suffix: String,
                           tint: Color, tag: (text: String, tint: Color)) -> some View {
        GlassCard {
            VStack(alignment: .center, spacing: 8) {
                HStack(spacing: 6) {
                    ZStack {
                        Circle().fill(tint.opacity(0.12)).frame(width: 24, height: 24)
                        Image(systemName: icon).font(.system(size: 10, weight: .semibold)).foregroundStyle(tint)
                    }
                    Text(title).font(CMFont.labelMd).foregroundStyle(CMColor.inkSoft)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value).font(CMFont.inter(28, .heavy)).foregroundStyle(CMColor.ink)
                    Text(suffix).font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft)
                }
                Text(tag.text).font(CMFont.inter(11, .semibold)).foregroundStyle(tag.tint)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(tag.tint.opacity(0.12), in: Capsule())
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview { ProfileView().environmentObject(AppState()) }

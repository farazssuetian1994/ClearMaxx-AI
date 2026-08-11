//
//  AboutView.swift
//  ClearMaxx — About sheet: app info, version, developer credit.
//

import SwiftUI

struct AboutView: View {
    @ObserveInjection var inject
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private let linkedInURL = URL(string: "https://www.linkedin.com/in/farazmasroor/")!

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        DewyBackground {
            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(CMColor.ink).frame(width: 36, height: 36)
                                .background(CMColor.cardSoft, in: Circle())
                        }.buttonStyle(.plain)
                    }

                    Circle().fill(CMGradient.auraDiagonal).frame(width: 88, height: 88)
                        .overlay(Image(systemName: "sparkles").font(.system(size: 36)).foregroundStyle(.white))
                        .padding(.top, 4)

                    VStack(spacing: 4) {
                        ClearMaxxWordmark(size: 26)
                        Text("Version \(appVersion) (\(buildNumber))")
                            .font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft)
                    }

                    Text("ClearMaxx uses AI-powered skin analysis to help you track your skin's health over time and build a daily routine tailored to your own results.")
                        .font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)

                    // Developer credit — tapping anywhere on the card opens the LinkedIn profile.
                    Button {
                        openURL(linkedInURL)
                    } label: {
                        GlassCard {
                            VStack(spacing: 4) {
                                Text("Made by").font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft)

                                Image("DeveloperAvatar")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 76, height: 76)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(CMGradient.aura, lineWidth: 2.5))
                                    .shadow(color: CMColor.violet.opacity(0.25), radius: 10, y: 4)
                                    .padding(.top, 2)
                                    .padding(.bottom, 6)

                                Text("Faraz Masroor").font(CMFont.title).foregroundStyle(CMColor.ink)

                                HStack(spacing: 6) {
                                    Image(systemName: "link").font(.system(size: 11, weight: .semibold))
                                    Text("View LinkedIn profile").font(CMFont.labelSm)
                                }
                                .foregroundStyle(CMColor.violet)
                                .padding(.top, 6)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Made by Faraz Masroor. Opens LinkedIn profile.")

                    Spacer(minLength: 40)
                }
                .padding(24)
            }
        }
    }
}

#Preview { AboutView() }

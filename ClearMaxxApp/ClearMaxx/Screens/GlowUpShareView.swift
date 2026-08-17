//
//  GlowUpShareView.swift
//  ClearMaxx — before/after celebration + share card, fed real scan data.
//

import SwiftUI

struct GlowUpShareView: View {
    @ObserveInjection var inject
    @Environment(\.dismiss) private var dismiss
    @State private var slider: CGFloat = 0.5
    @State private var saveConfirmation = false
    @State private var showShareSheet = false

    var beforeImage: UIImage? = nil
    var afterImage: UIImage? = nil
    var scoreDelta: Int = 0
    var beforeScore: Int = 0
    var afterScore: Int = 0
    var resolvedMetricNames: [String] = []
    /// Non-nil when shown as a post-scan celebration (adds a "Continue" button);
    /// nil when shown as the plain "Share My Glow-Up" sheet from Progress.
    var onContinue: (() -> Void)? = nil

    var body: some View {
        DewyBackground {
            ScrollView {
                VStack(spacing: 20) {
                    header

                    if !resolvedMetricNames.isEmpty {
                        Text("\(resolvedMetricNames.joined(separator: " & ")) Cleared! 🎉")
                            .font(CMFont.headlineMd).foregroundStyle(CMColor.ink)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    VStack(spacing: 14) {
                        BeforeAfterSlider(value: $slider, beforeImage: beforeImage, afterImage: afterImage)
                            .frame(height: 320)

                        scoreCard
                        credibilityCard
                    }
                    .padding(.horizontal, 24)

                    VStack(spacing: 4) {
                        Text("Flex your glow ✨").font(CMFont.headlineMd).foregroundStyle(CMColor.ink)
                        Text("Share your progress and inspire others")
                            .font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                    }
                    .multilineTextAlignment(.center)

                    HStack(spacing: 14) {
                        shareButton("TikTok", "music.note", AnyShapeStyle(Color.black))
                        shareButton("Instagram", "camera.fill", AnyShapeStyle(
                            LinearGradient(colors: [Color(hex: "F58529"), Color(hex: "DD2A7B"), Color(hex: "8134AF")],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)))
                    }
                    .padding(.horizontal, 24)

                    AuraButton(title: saveConfirmation ? "Saved!" : "Save to Photos",
                               systemImage: saveConfirmation ? "checkmark" : "square.and.arrow.down") {
                        saveToPhotos()
                    }
                    .padding(.horizontal, 24)

                    if let onContinue {
                        Button("Continue", action: onContinue)
                            .font(CMFont.labelMd).foregroundStyle(CMColor.violetDeep)
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showShareSheet) {
            if let afterImage { ActivityView(items: [afterImage]) }
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold)).foregroundStyle(CMColor.ink)
            }
            Spacer(); ClearMaxxWordmark(size: 22); Spacer()
            Image(systemName: "chevron.left").opacity(0)
        }
        .padding(.horizontal, 24).padding(.top, 12)
    }

    // MARK: ClearScore change stat card

    private var scoreDeltaText: String {
        scoreDelta >= 0 ? "+\(scoreDelta) Points" : "\(scoreDelta) Points"
    }

    private var scoreCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    ZStack {
                        Circle().fill(CMColor.primary.opacity(0.12)).frame(width: 24, height: 24)
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(CMColor.primary)
                    }
                    Text("ClearScore Change").font(CMFont.labelMd).foregroundStyle(CMColor.inkSoft)
                }
                Text(scoreDeltaText).font(CMFont.inter(26, .heavy)).foregroundStyle(CMColor.primary)
            }
            Spacer(minLength: 8)
            Rectangle().fill(CMColor.outline.opacity(0.6)).frame(width: 1, height: 46)
            Spacer(minLength: 8)
            VStack(alignment: .leading, spacing: 8) {
                Text("ClearScore").font(CMFont.labelMd).foregroundStyle(CMColor.inkSoft)
                HStack(spacing: 8) {
                    scorePair(beforeScore, tint: CMColor.ink)
                    Image(systemName: "arrow.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(CMColor.inkSoft)
                    scorePair(afterScore, tint: CMColor.primary)
                }
            }
        }
        .padding(18)
        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func scorePair(_ value: Int, tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text("\(value)").font(CMFont.inter(22, .heavy)).foregroundStyle(tint)
            Text("/100").font(CMFont.inter(10, .semibold)).foregroundStyle(CMColor.inkSoft)
        }
    }

    // MARK: Credibility strip

    private var credibilityCard: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                ClearMaxxWordmark(size: 15)
                Text("AI Dermatology Analysis").font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft)
            }
            Spacer(minLength: 4)
            credibilityBadge(icon: "checkmark.shield.fill", text: "Clinically\nBacked AI")
            Spacer(minLength: 4)
            credibilityBadge(icon: "checkmark.seal.fill", text: "Verified\nResult")
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func credibilityBadge(icon: String, text: String) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().fill(CMColor.primary.opacity(0.12)).frame(width: 34, height: 34)
                Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(CMColor.primary)
            }
            Text(text).font(CMFont.inter(10, .semibold)).foregroundStyle(CMColor.inkSoft)
                .multilineTextAlignment(.center).lineLimit(2)
        }
    }

    // MARK: Actions

    private func saveToPhotos() {
        guard let afterImage else { return }
        UIImageWriteToSavedPhotosAlbum(afterImage, nil, nil, nil)
        saveConfirmation = true
    }

    private func shareButton(_ label: String, _ icon: String, _ bg: AnyShapeStyle) -> some View {
        Button { showShareSheet = true } label: {
            HStack(spacing: 8) {
                Image(systemName: icon); Text(label).font(CMFont.labelMd)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(bg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview { GlowUpShareView() }

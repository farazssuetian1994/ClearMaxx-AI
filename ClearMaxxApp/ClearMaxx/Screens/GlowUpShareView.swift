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

    var beforeImage: UIImage? = nil
    var afterImage: UIImage? = nil
    var scoreDelta: Int = 0
    var resolvedMetricNames: [String] = []
    /// Non-nil when shown as a post-scan celebration (adds a "Continue" button);
    /// nil when shown as the plain "Share My Glow-Up" sheet from Progress.
    var onContinue: (() -> Void)? = nil

    var body: some View {
        DewyBackground {
            ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold)).foregroundStyle(CMColor.ink)
                    }
                    Spacer(); ClearMaxxWordmark(size: 22); Spacer()
                    Image(systemName: "chevron.left").opacity(0)
                }
                .padding(.horizontal, 24).padding(.top, 12)

                if !resolvedMetricNames.isEmpty {
                    Text("\(resolvedMetricNames.joined(separator: " & ")) Cleared! 🎉")
                        .font(CMFont.headlineMd).foregroundStyle(CMColor.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Share card
                VStack(spacing: 0) {
                    BeforeAfterSlider(value: $slider, beforeImage: beforeImage, afterImage: afterImage)
                        .frame(height: 300)
                        .overlay(alignment: .bottom) {
                            VStack(spacing: 2) {
                                Text(scoreDeltaText).font(CMFont.inter(26, .heavy)).foregroundStyle(.white)
                                Text("ClearScore change").font(CMFont.labelMd).foregroundStyle(.white.opacity(0.9))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(CMGradient.aura.opacity(0.92))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                    HStack {
                        ClearMaxxWordmark(size: 16)
                        Text("AI Dermatology Analysis").font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft)
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(CMColor.violet)
                            Text("Verified Result").font(CMFont.labelSm).foregroundStyle(CMColor.violetDeep)
                        }
                    }
                    .padding(14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.top, 10)
                }
                .padding(.horizontal, 24)

                Text("Flex your glow").font(CMFont.headlineMd).foregroundStyle(CMColor.ink)

                HStack(spacing: 14) {
                    shareButton("TikTok", "music.note", .black)
                    shareButton("Instagram", "camera.fill", nil)
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
    }

    private var scoreDeltaText: String {
        scoreDelta >= 0 ? "+\(scoreDelta) ClearScore" : "\(scoreDelta) ClearScore"
    }

    private func saveToPhotos() {
        guard let afterImage else { return }
        UIImageWriteToSavedPhotosAlbum(afterImage, nil, nil, nil)
        saveConfirmation = true
    }

    private func shareButton(_ label: String, _ icon: String, _ bg: Color?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon); Text(label).font(CMFont.labelMd)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity).padding(.vertical, 16)
        .background(bg != nil ? AnyShapeStyle(bg!) : AnyShapeStyle(CMGradient.aura),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview { GlowUpShareView() }

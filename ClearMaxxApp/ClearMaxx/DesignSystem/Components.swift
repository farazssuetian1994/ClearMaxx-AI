//
//  Components.swift
//  ClearMaxx — reusable UI components (glass cards, aura buttons, score ring, chips...)
//

import SwiftUI

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white.opacity(0.78))
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.6), lineWidth: 1))
            .bloomShadow()
    }
}

// MARK: - Aura Button (primary pill)

struct AuraButton: View {
    let title: String
    var systemImage: String? = nil
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                if let systemImage { Image(systemName: systemImage) }
            }
            .font(CMFont.inter(18, .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(CMGradient.aura, in: Capsule())
            .shadow(color: CMColor.coral.opacity(0.35), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Secondary / glass pill button

struct GlassPillButton: View {
    let systemImage: String
    var action: () -> Void = {}
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(CMColor.ink)
                .frame(width: 56, height: 56)
                .background(.white, in: Circle())
                .bloomShadow()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tag chip

struct TagChip: View {
    let text: String
    var tint: Color = CMColor.coral
    var filled: Bool = false
    var icon: String? = nil
    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.system(size: 10, weight: .semibold)) }
            Text(text).font(CMFont.labelSm).lineLimit(1)
        }
        .foregroundStyle(filled ? .white : tint)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(
            Capsule().fill(filled ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.12))))
    }
}

// MARK: - Section label (uppercase category tag)

struct CategoryLabel: View {
    let text: String
    var color: Color = CMColor.violetDeep
    var body: some View {
        Text(text.uppercased())
            .font(CMFont.inter(11, .bold))
            .tracking(1.2)
            .foregroundStyle(color)
    }
}

// MARK: - Score Ring (Aura gradient progress ring)

struct ScoreRing: View {
    let score: Int           // 0...100
    var size: CGFloat = 120
    var lineWidth: CGFloat = 12
    var caption: String = "CLEARSCORE"

    private var progress: Double { Double(max(0, min(100, score))) / 100 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(CMColor.cardSoft, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(CMGradient.aura,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(CMFont.inter(size * 0.32, .heavy))
                    .foregroundStyle(CMColor.ink)
                Text(caption)
                    .font(CMFont.inter(size * 0.075, .bold))
                    .tracking(1)
                    .foregroundStyle(CMColor.inkSoft)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Scan hero card (score ring + trend badge + headline + confidence footer)

struct ScanHeroCard: View {
    let score: Int
    var badge: (text: String, tint: Color)? = nil
    let headline: String
    var summary: String? = nil
    var confidence: Int? = nil

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [CMColor.primary.opacity(0.16), CMColor.primary.opacity(0.05)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
            sparkles

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    ScoreRing(score: score, size: 128, lineWidth: 13, caption: "AI SCORE")
                    Spacer()
                    if let badge {
                        Text(badge.text).font(CMFont.labelSm).foregroundStyle(badge.tint)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(badge.tint.opacity(0.15), in: Capsule())
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(headline).font(CMFont.headlineMd).foregroundStyle(CMColor.ink)
                    if let summary, !summary.isEmpty {
                        Text(summary).font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let confidence {
                    Divider()
                    HStack {
                        Image(systemName: "checkmark.shield.fill").foregroundStyle(CMColor.success)
                        Text("AI scan complete").font(CMFont.labelMd).foregroundStyle(CMColor.ink)
                        Spacer()
                        Text("\(confidence)% confidence").font(CMFont.labelMd).foregroundStyle(CMColor.coralDeep)
                    }
                }
            }
            .padding(22)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var sparkles: some View {
        ZStack {
            Image(systemName: "sparkle").font(.system(size: 14)).foregroundStyle(CMColor.primary.opacity(0.35))
                .position(x: 34, y: 40)
            Image(systemName: "sparkle").font(.system(size: 20)).foregroundStyle(CMColor.primary.opacity(0.25))
                .position(x: 320, y: 90)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Encouragement tip card

struct TipCard: View {
    let title: String
    let message: String
    var icon: String = "sparkle"
    var tint: Color = CMColor.success
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(tint.opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: icon).foregroundStyle(tint).font(.system(size: 18, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(CMFont.labelMd).foregroundStyle(tint)
                Text(message).font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
            }
            Spacer(minLength: 8)
            if action != nil { Image(systemName: "chevron.right").foregroundStyle(CMColor.outline) }
        }
        .padding(16)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { action?() }
    }
}

// MARK: - Metric bar (per-issue severity)

struct MetricBar: View {
    let label: String
    let value: Int           // 0...100
    var tint: Color = CMColor.coral

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label).font(CMFont.labelMd).foregroundStyle(CMColor.ink)
                Spacer()
                Text("\(value)").font(CMFont.labelMd).foregroundStyle(tint)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(CMColor.cardSoft).frame(height: 8)
                    Capsule().fill(tint)
                        .frame(width: geo.size.width * CGFloat(value) / 100, height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Dewy background wrapper

struct DewyBackground<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        // Apply the gradient as a safe-area-ignoring *background* rather than a
        // ZStack sibling. A sibling that ignores the safe area inflates the
        // ScrollView's resolved scroll region on iOS 26, which lets it
        // over-scroll into dead space and stick. As a background, the content
        // (ScrollView) keeps correct safe-area insets while the gradient still
        // bleeds to every edge.
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CMGradient.dewy.ignoresSafeArea())
    }
}

// MARK: - Top bar with wordmark

struct CMTopBar: View {
    var showBack: Bool = false
    var onBack: () -> Void = {}
    var trailing: AnyView? = nil

    var body: some View {
        HStack {
            if showBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(CMColor.ink)
                }
            }
            Spacer()
            ClearMaxxWordmark(size: 22)
            Spacer()
            if let trailing { trailing } else {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(CMColor.ink)
                    .opacity(showBack ? 1 : 0)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}

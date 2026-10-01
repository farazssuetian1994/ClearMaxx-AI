//
//  GoPremiumView.swift
//  ClearMaxx — paywall. "Elevate Your Glow", plan picker, feature list, trial CTA.
//
//  Every number on this screen — price, period, saving, trial length — is derived
//  from the live StoreProduct rather than written into the copy. Prices and
//  introductory offers are edited in App Store Connect, and hardcoded figures go
//  stale silently: a wrong saving or a wrong trial length on the purchase screen
//  is both a lie to the user and an App Store guideline 3.1.2 rejection.
//

import SwiftUI
import RevenueCat

struct GoPremiumView: View {
    @ObserveInjection var inject
    /// When true this is the post-quiz gate rather than the optional upsell:
    /// no close button, no swipe-to-dismiss, and success advances the app stage
    /// instead of dismissing a sheet. Mirrors the ChartSense hard-paywall model.
    var hardGate: Bool = false
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.layoutDirection) private var layoutDirection

    @State private var offering: Offering?
    @State private var selected: Package?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    /// True once we've tried to load offerings and come back with nothing.
    /// A hard gate with no purchasable product and no close button would trap
    /// the user for good, so this drives a retry + fail-open escape.
    @State private var storeUnavailable = false
    @State private var isLoadingOfferings = true

    private let privacyURL = URL(string: "https://clearmaxxai.blogspot.com/p/privacy-policy.html")!
    private let termsURL = URL(string: "https://clearmaxxai.blogspot.com/p/terms-of-service.html")!

    // MARK: - Plans

    /// Yearly first: it is the best value for the user and the best retention for
    /// the app, so it leads and is pre-selected.
    private static let planOrder: [PackageType] = [.annual, .monthly, .weekly]

    private var plans: [Package] {
        guard let packages = offering?.availablePackages else { return [] }
        let ranked = packages
            .filter { Self.planOrder.contains($0.packageType) }
            .sorted {
                (Self.planOrder.firstIndex(of: $0.packageType) ?? .max)
                    < (Self.planOrder.firstIndex(of: $1.packageType) ?? .max)
            }
        // Never render an empty paywall: if the offering is built from custom
        // package types we don't recognise, show whatever it does have.
        return ranked.isEmpty ? packages : ranked
    }

    private var weeklyPlan: Package? { plans.first { $0.packageType == .weekly } }

    private func planTitle(for package: Package) -> String {
        switch package.packageType {
        case .weekly: return L("premium.weekly")
        case .monthly: return L("premium.monthly")
        case .annual: return L("premium.yearly")
        default: return package.storeProduct.localizedTitle
        }
    }

    private func periodSuffix(for package: Package) -> String {
        switch package.packageType {
        case .weekly: return L("premium.perWeek")
        case .monthly: return L("premium.perMonth")
        case .annual: return L("premium.perYear")
        default: return ""
        }
    }

    /// See `PaywallPricing` — the arithmetic lives there so it can be tested.
    private func savingsPercent(for package: Package) -> Int? {
        guard package.packageType != .weekly else { return nil }
        return PaywallPricing.savingsPercent(
            planPricePerWeek: package.storeProduct.pricePerWeek?.doubleValue,
            weeklyBaseline: weeklyPlan?.storeProduct.pricePerWeek?.doubleValue)
    }

    /// "Just $1.35/week — vs $4.99/week": the same unit on both plans, so the
    /// user doesn't have to divide to see which is the cheaper way to buy.
    private func perWeekCompare(for package: Package) -> String? {
        guard package.packageType != .weekly,
              savingsPercent(for: package) != nil,
              let perWeek = package.storeProduct.localizedPricePerWeek,
              let weekly = weeklyPlan?.storeProduct.localizedPriceString else { return nil }
        return L("premium.perWeekCompare", perWeek, weekly)
    }

    /// The store's own free-trial terms for this package. Never assume a trial
    /// is three days: ClearMaxx's yearly product grants a week while weekly and
    /// monthly grant three, so each plan states its own terms.
    private func freeTrial(for package: Package) -> String? {
        PaywallPricing.freeTrialDuration(for: package.storeProduct,
                                         locale: CMLocale.shared.foundationLocale)
    }

    // MARK: - CTA copy

    private var ctaTitle: String {
        if isPurchasing { return L("premium.purchasing") }
        guard let selected else { return L("premium.selectPlan") }
        return freeTrial(for: selected) != nil ? L("premium.startTrial") : L("premium.continue")
    }

    /// States the exact terms of the plan the user is about to buy: the trial
    /// length if the product has one, then the price and the period it renews on.
    private var ctaSubtext: String? {
        guard let selected else { return nil }
        let price = selected.storeProduct.localizedPriceString + periodSuffix(for: selected)
        if let trial = freeTrial(for: selected) {
            return L("premium.freeTrialThen", trial, price)
        }
        return L("premium.thenPrice", price)
    }

    private var features: [(String, String, String)] {
        [
            ("flame.fill", L("premium.feature1.title"), L("premium.feature1.body")),
            ("leaf.fill", L("premium.feature2.title"), L("premium.feature2.body")),
            ("shield.lefthalf.filled", L("premium.feature3.title"), L("premium.feature3.body"))
        ]
    }

    // MARK: - Body

    var body: some View {
        DewyBackground {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        header
                        hero
                        planList
                        featureCard
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
                // The CTA and the legal footer are pinned rather than scrolled.
                // Previously they sat below the fold on a 6.1" screen, so the
                // first thing a user saw had no way forward on it.
                bottomBar
            }
        }
        .interactiveDismissDisabled(hardGate)
        .task { await loadOfferings() }
        .enableInjection()
    }

    private var header: some View {
        HStack {
            // Hard gate: no close button and no dismiss gesture — the user
            // subscribes or restores to continue. Restore / Terms / Privacy
            // stay below for App Store compliance.
            if hardGate {
                Image(systemName: "xmark").opacity(0)
            } else {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(CMColor.inkSoft)
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.7), in: Circle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
            ClearMaxxWordmark(size: 20)
            Spacer()
            Image(systemName: "xmark").opacity(0).frame(width: 32)
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            Circle().fill(CMGradient.auraDiagonal).frame(width: 66, height: 66)
                .overlay(Image(systemName: "sparkles").font(.system(size: 28)).foregroundStyle(.white))
                .overlay(alignment: .bottom) {
                    Text(L("premium.plus")).font(CMFont.inter(9, .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(CMColor.primaryDark, in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.9), lineWidth: 2))
                        .offset(y: 8)
                }
                .shadow(color: CMColor.primary.opacity(0.4), radius: 18, y: 8)
                .padding(.bottom, 6)

            Text(L("premium.title"))
                .font(CMFont.inter(29, .heavy)).foregroundStyle(CMColor.ink)
                .multilineTextAlignment(.center).minimumScaleFactor(0.7)
            Text(L("premium.subtitle"))
                .font(CMFont.inter(14, .regular)).foregroundStyle(CMColor.inkSoft)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Plans

    @ViewBuilder
    private var planList: some View {
        if isLoadingOfferings {
            // A spinner, not placeholder prices. Showing a guessed price that
            // then changes under the user is worse than showing none.
            VStack(spacing: 10) {
                ProgressView()
                Text(L("premium.loadingPlans")).font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 36)
        } else {
            VStack(spacing: 10) {
                ForEach(plans, id: \.identifier) { package in
                    planCard(package)
                }
            }
        }
    }

    private func planCard(_ package: Package) -> some View {
        let isSelected = selected?.identifier == package.identifier
        let savings = savingsPercent(for: package)
        let compare = perWeekCompare(for: package)

        return Button {
            selected = package
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(planTitle(for: package))
                        .font(CMFont.inter(15, .bold)).foregroundStyle(CMColor.inkSoft)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(package.storeProduct.localizedPriceString)
                            .font(CMFont.inter(24, .heavy)).foregroundStyle(CMColor.ink)
                        Text(periodSuffix(for: package))
                            .font(CMFont.inter(13, .medium)).foregroundStyle(CMColor.inkSoft)
                    }
                    if let compare {
                        Text(compare).font(CMFont.inter(12, .semibold)).foregroundStyle(CMColor.primaryDark)
                    }
                }
                Spacer(minLength: 0)
                ZStack {
                    Circle().stroke(isSelected ? CMColor.primary : CMColor.border, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Circle().fill(CMGradient.aura).frame(width: 24, height: 24)
                        Circle().fill(.white).frame(width: 9, height: 9)
                    }
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? AnyShapeStyle(CMGradient.aura) : AnyShapeStyle(CMColor.border),
                            lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: CMColor.primary.opacity(isSelected ? 0.18 : 0), radius: 14, y: 6)
            .overlay(alignment: .topTrailing) {
                if let savings {
                    Text(L("premium.saveBadge", savings))
                        .font(CMFont.inter(10, .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(CMGradient.aura, in: Capsule())
                        .shadow(color: CMColor.primary.opacity(0.35), radius: 6, y: 2)
                        // SwiftUI mirrors `.topTrailing` in right-to-left layouts
                        // but does NOT mirror `.offset(x:)` — it is raw
                        // coordinates. A fixed -14 would shove the badge off the
                        // outer edge in Arabic instead of tucking it inside.
                        .offset(x: layoutDirection == .rightToLeft ? 14 : -14, y: -9)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.18), value: isSelected)
    }

    private var featureCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(L("premium.includedTitle"))
                    .font(CMFont.inter(14, .bold)).foregroundStyle(CMColor.ink)
                ForEach(Array(features.enumerated()), id: \.offset) { _, f in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: f.0).font(.system(size: 15))
                            .foregroundStyle(CMColor.primary)
                            .frame(width: 34, height: 34)
                            .background(CMColor.primary.opacity(0.1),
                                        in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.1).font(CMFont.inter(15, .bold)).foregroundStyle(CMColor.ink)
                            Text(f.2).font(CMFont.inter(13, .regular)).foregroundStyle(CMColor.inkSoft)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    // MARK: Pinned bottom bar

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if let errorMessage {
                Text(errorMessage).font(CMFont.labelSm).foregroundStyle(CMColor.error)
                    .multilineTextAlignment(.center)
            }

            if storeUnavailable {
                // Fail open. Being unable to reach the App Store is our problem,
                // not the user's, and a dead-end launch screen is both a terrible
                // first run and an App Store rejection.
                Text(L("premium.storeUnavailable"))
                    .font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft)
                    .multilineTextAlignment(.center)
                AuraButton(title: L("common.tryAgain"), systemImage: "arrow.clockwise") {
                    Task { await loadOfferings() }
                }
                if hardGate {
                    Button(L("premium.continueWithoutPlan")) { state.stage = .main }
                        .font(CMFont.labelMd).foregroundStyle(CMColor.primaryDark)
                }
            } else {
                Button(action: purchase) {
                    HStack(spacing: 10) {
                        if isPurchasing {
                            ProgressView().tint(.white)
                        }
                        Text(ctaTitle)
                        if !isPurchasing && selected != nil {
                            Image(systemName: "arrow.right").font(.system(size: 15, weight: .bold))
                        }
                    }
                    .font(CMFont.inter(17, .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 17)
                    .background(CMGradient.aura, in: Capsule())
                    .shadow(color: CMColor.primary.opacity(0.35), radius: 14, y: 8)
                    .opacity(ctaDisabled ? 0.55 : 1)
                }
                .buttonStyle(.plain)
                .disabled(ctaDisabled)

                if let ctaSubtext {
                    Text(ctaSubtext).font(CMFont.inter(12, .semibold)).foregroundStyle(CMColor.ink)
                        .multilineTextAlignment(.center)
                }
                // Auto-renewal terms stated on the purchase screen itself —
                // required by App Store Review guideline 3.1.2.
                Text(L("premium.autoRenew"))
                    .font(CMFont.inter(10, .medium)).foregroundStyle(CMColor.inkSoft)
                    .multilineTextAlignment(.center).lineSpacing(1)
            }

            // German and Russian compounds ("Nutzungsbedingungen",
            // "Datenschutzerklärung") are far wider than the English labels and
            // were wrapping mid-word. Each link keeps to one line and shrinks to
            // fit instead of hyphenating itself across two.
            HStack(spacing: 6) {
                Button(L("premium.terms")) { openURL(termsURL) }
                Text("·").foregroundStyle(CMColor.border)
                Button(L("premium.privacy")) { openURL(privacyURL) }
                Text("·").foregroundStyle(CMColor.border)
                Button(L("premium.restore")) { restore() }.fontWeight(.bold)
            }
            .font(CMFont.inter(12, .medium)).foregroundStyle(CMColor.inkSoft)
            .buttonStyle(.plain)
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .padding(.top, 2)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(alignment: .top) {
            // Near-opaque, not a light material: the feature card scrolls under
            // this bar, and at 85% the text bled through and read as a rendering
            // bug rather than as content continuing behind a pinned footer.
            CMColor.surface.opacity(0.98)
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    Rectangle().fill(CMColor.border).frame(height: 1)
                }
                .shadow(color: CMColor.ink.opacity(0.06), radius: 10, y: -4)
        }
    }

    private var ctaDisabled: Bool { isPurchasing || selected == nil || isLoadingOfferings }

    // MARK: - Store

    private func loadOfferings() async {
        isLoadingOfferings = true
        storeUnavailable = false
        let loaded = try? await PurchaseService.shared.fetchOfferings()
        offering = loaded
        // No offering, or one with nothing to sell, means there is nothing the
        // user could possibly tap to get past this screen.
        storeUnavailable = (loaded?.availablePackages.isEmpty ?? true)
        selected = plans.first { $0.packageType == .annual } ?? plans.first
        isLoadingOfferings = false
    }

    /// The gate releases to the app; the optional upsell just closes.
    private func proceedAfterEntitlement() {
        if hardGate { state.stage = .main } else { dismiss() }
    }

    private func purchase() {
        guard let package = selected else { return }
        isPurchasing = true
        errorMessage = nil
        Task {
            do {
                let outcome = try await PurchaseService.shared.purchase(package)
                isPurchasing = false
                switch outcome {
                case .entitled:
                    state.isPremium = true
                    proceedAfterEntitlement()
                case .cancelled:
                    // The user closed the sheet. Nothing went wrong, so say nothing.
                    break
                case .notConfirmed:
                    // Apple's review flagged a user whose purchase went through
                    // being left on the paywall with no explanation. If even a
                    // forced re-fetch can't confirm it, say so plainly.
                    state.isPremium = false
                    errorMessage = L("premium.purchaseNotConfirmed")
                }
            } catch {
                isPurchasing = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func restore() {
        isPurchasing = true
        errorMessage = nil
        Task {
            do {
                let entitled = try await PurchaseService.shared.restorePurchases()
                state.isPremium = entitled
                isPurchasing = false
                if entitled { proceedAfterEntitlement() } else { errorMessage = L("premium.noSubscription") }
            } catch {
                isPurchasing = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview { GoPremiumView().environmentObject(AppState()) }

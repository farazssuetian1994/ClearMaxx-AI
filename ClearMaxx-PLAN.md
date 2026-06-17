# ClearMaxx — Product Plan

> AI Skin & Face Scanner. Scan → detect issues → explain → personalized routine → daily progress tracking.
> Platform: React Native (Expo). Audience: Gen Z & Millennials. Market: US-first.

---

## 1. Competitor Analysis

| App | What they offer | Weakness / gap you exploit |
|-----|----------------|----------------------------|
| **Skinly (AI Skin Scanner)** | 10+ metrics (clarity, hydration, texture, pores, wrinkles, redness, acne, dark circles, spots, skin age), routine, product scan, cycle tracking | Cluttered; analysis behind hard paywall; weak "why this is happening" explanations |
| **GlowScan AI** | Face/body/hair/lip scan, routine tracker, skin signals | Spreads thin across body parts; shallow per-issue depth |
| **Skinmax** | Scan glow/acne/hydration, skin age, "younger look" framing, daily routine | Generic recommendations; no strong trigger/cause analysis |
| **MDacne** | Dermatologist-built, custom acne treatment, sells its own product kit | Acne-only; expensive ($24/mo + product); medical/clinical feel, not fun |
| **Curology** | Rx prescription skincare, ships custom formulas | Requires prescription + product subscription; US-telehealth heavy; not a pure scanner |
| **TroveSkin** | Skin diary, AI scan, tracker | Dated UX, less viral |
| **Clearly / Clear AI / Clear** | Acne scanner, daily tasks, social skincare tracker | Either acne-only or community-only; no all-in-one |
| **YouCam (Perfect Corp)** | 15-condition AI analysis + AR makeup | Beauty/makeup focus, B2B roots, not habit-driven |
| **Yuka / SkinSort / OnSkin** | Product & ingredient scanners | Only ingredients — no face analysis or progress |

### The differentiation gap to win (do ALL FOUR in one app — most do 1–2):
1. **Daily progress tracking** with before/after trend graphs per issue
2. **Cause/trigger analysis** — connect breakouts to sleep, diet, stress, products (the "WHY", almost nobody does this well)
3. **AM/PM personalized routine** generated from the scan
4. **Ingredient/product suitability** check against your detected skin profile

---

## 2. Competitor Subscription Pricing (2026)

| App | Price | Model |
|-----|-------|-------|
| **GlowScan AI** | **$8.99/mo** or **$24.99/yr**, 3-day free trial | Freemium hard paywall |
| **MDacne** | **$24/mo** (~$288/yr), trial = $9 shipping | Subscription + product kit |
| **Curology** | **$4.95–$39.95 per shipment** | Rx + product subscription |
| **Skinmax / Umax-style scanners** | Typically **$4.99–$6.99/week** or **$29.99–$69.99/yr** | Aggressive weekly paywall after first scan |
| **Industry norm (consumer AI scanner)** | **Weekly $4.99–6.99**, **Yearly $39.99–69.99**, 3-day trial | "Soft" free scan, paywall the full report |

### Recommended ClearMaxx pricing
- **Free:** 1 full scan + basic scores (the hook).
- **Weekly:** **$5.99/week** (impulse / TikTok traffic converts on weekly).
- **Yearly:** **$39.99/year** with **3-day free trial** (anchor the weekly against this to push annual).
- **Lifetime (optional):** $79.99 one-time (captures commitment-averse users).
- Always show yearly as "**$0.77/week, billed annually**" next to the weekly to make annual look cheap.

---

## 3. ClearMaxx Feature Plan

### MVP (v1 — ship this first)
1. **Onboarding quiz** — skin type, goals (clear acne / glow / anti-aging), age, concerns. Builds personalization + primes paywall.
2. **AI Face Scan** — camera with face-frame guide + lighting check. Detects: acne, oiliness, dark spots/PIH, dark circles, redness, pores, wrinkles, texture, dryness, hydration, skin age.
3. **Results dashboard** — overall **ClearScore (0–100)** + per-issue severity bars + face heatmap overlay.
4. **"What this means"** — plain-English explanation per detected issue.
5. **Personalized AM/PM routine** — steps + recommended ingredients (niacinamide, salicylic acid, retinol, SPF...).
6. **Daily scan + progress** — same-angle capture, before/after slider, trend graph per metric.
7. **Reminders / streaks** — daily scan + routine push notifications (habit loop = retention).
8. **Paywall** — after first full scan.

### V2 (the moat — what beats competitors)
9. **Trigger correlation engine** — log sleep, water, diet, stress, period, products → AI surfaces "breakouts spike ~2 days after dairy."
10. **Ingredient / product scanner** — scan label/barcode → "good or bad for YOUR profile."
11. **Shareable glow-up card** — animated before/after with score gain → built for TikTok virality.
12. **AI skin coach chat** — ask questions, get routine tweaks (Claude API).

### V3 (scale)
13. Community / leaderboards (clear-skin streaks), dermatologist marketplace, affiliate product shop.

---

## 4. How ClearMaxx Beats Them
- **One app, all four pillars** (scan + cause + routine + ingredients). Rivals silo these.
- **"WHY" engine** (trigger correlation) — the emotional payoff nobody nails.
- **Virality built-in** — shareable glow-up cards drive free TikTok installs (looksmaxxing trend).
- **Fun, Gen-Z UX** — not clinical like MDacne/Curology.
- **Fair pricing** — $39.99/yr undercuts GlowScan's annualized + MDacne, no forced product purchase.

---

## 5. Tech Stack
- **React Native (Expo)** — `expo-camera`, `expo-image-picker`, `expo-notifications`
- **Navigation:** `expo-router` or React Navigation
- **State:** Zustand or Redux Toolkit
- **Backend:** Supabase (auth, DB, storage for scan photos) or Firebase
- **AI analysis:** start with a 3rd-party skin API (Perfect Corp / Haut.ai) OR Claude vision via your server; move to custom model later
- **Payments:** RevenueCat (handles App Store + Play subscriptions, paywalls, trials)
- **Charts:** `react-native-gifted-charts` / `victory-native`

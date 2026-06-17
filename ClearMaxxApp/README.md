# ClearMaxx — SwiftUI App

AI Skin & Face Scanner. Native **SwiftUI** implementation of the 12 Stitch "Radiance Aesthetic" screens.

> ⚠️ **SwiftUI requires macOS + Xcode to build and run.** This code was authored on Windows and
> cannot be compiled here. Move this `ClearMaxxApp` folder to a Mac (or a cloud Mac like
> MacStadium / GitHub Actions macOS runner) and open it in **Xcode 16 or newer**.

## Run it (on a Mac)

1. Copy the `ClearMaxxApp` folder to your Mac.
2. Double-click **`ClearMaxx.xcodeproj`** to open it in Xcode 16+.
3. Select an iPhone simulator (e.g. iPhone 15) or a connected device.
4. Press **⌘R**.

The project uses Xcode's **file-system synchronized groups**, so every `.swift` file inside
`ClearMaxx/` is compiled automatically — no need to add files manually.

### If you're on Xcode 15 or older (synchronized groups unsupported)
Create the project fresh and drop the code in:
1. Xcode → **File ▸ New ▸ Project ▸ iOS ▸ App**. Name it `ClearMaxx`, Interface **SwiftUI**, Language **Swift**.
2. Delete the auto-generated `ContentView.swift` and `ClearMaxxApp.swift`.
3. Drag the contents of this repo's `ClearMaxx/` folder into the Xcode project ("Copy items if needed", "Create groups").
4. In target settings ▸ Info, add **`NSCameraUsageDescription`** = "ClearMaxx uses the camera to scan and analyze your skin."
5. Build & run.

## Structure

```
ClearMaxx/
├─ ClearMaxxApp.swift          @main entry
├─ DesignSystem/
│  ├─ Theme.swift              Aura gradient, colors, fonts, wordmark
│  └─ Components.swift         GlassCard, AuraButton, ScoreRing, MetricBar, chips, tab styling
├─ Models/
│  └─ Models.swift             SkinMetric, RoutineStep, DiaryEntry, AppState (mock data)
├─ Navigation/
│  ├─ RootView.swift           splash → onboarding → quiz → main
│  └─ MainTabView.swift        custom glass bottom tab bar
├─ Screens/
│  ├─ SplashView.swift
│  ├─ OnboardingView.swift
│  ├─ SkinQuizView.swift
│  ├─ CameraScanView.swift     live AVFoundation front-camera preview + AR overlay + scan flow
│  ├─ AnalyzingView.swift
│  ├─ ResultsDashboardView.swift
│  ├─ IssueDetailView.swift
│  ├─ DailyRoutineView.swift
│  ├─ SkinProgressView.swift   before/after slider, trend, share sheet
│  ├─ SkinDiaryView.swift
│  ├─ GlowUpShareView.swift
│  ├─ GoPremiumView.swift      paywall (Weekly $5.99 / Yearly $39.99)
│  └─ ProfileView.swift
└─ Assets.xcassets/            AppIcon + AccentColor (add real icon art before release)
```

## Notes
- **Data is mocked** in `AppState`. Wire a real skin-analysis API or Claude vision where the scan completes (`AnalyzingView.onDone`).
- **Fonts:** the design calls for *Inter*; the code falls back to the system font. To match exactly,
  add the Inter `.ttf` files to the bundle + `UIAppFonts` and update `CMFont.inter(...)`.
- **Camera** works on a physical device; the simulator shows a black preview (no camera hardware).
- **Subscriptions:** `GoPremiumView` is UI-only. Integrate **RevenueCat** or StoreKit 2 for real purchases.

## Design system
"Radiance Aesthetic" — glassmorphism + minimalism. Aura Gradient **Coral `#FF7F50` → Violet `#8A2BE2`**,
dewy peach-lavender backgrounds, Inter type, 20px rounded glass cards, pill buttons, ClearScore ring.

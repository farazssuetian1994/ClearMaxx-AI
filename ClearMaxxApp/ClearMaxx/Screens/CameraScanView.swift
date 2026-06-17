//
//  CameraScanView.swift
//  ClearMaxx — Scan tab. Live front-camera preview with AR-style overlay + scan flow.
//

import SwiftUI
import AVFoundation

// MARK: - Scan flow routing

enum ScanRoute: Hashable { case analyzing, results, issue(SkinMetric) }

struct CameraScanView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScanCaptureScreen { path.append(ScanRoute.analyzing) }
                .navigationDestination(for: ScanRoute.self) { route in
                    switch route {
                    case .analyzing:
                        AnalyzingView { path.append(ScanRoute.results) }
                    case .results:
                        ResultsDashboardView(
                            onIssue: { path.append(ScanRoute.issue($0)) },
                            onRescan: { path = NavigationPath() })
                    case .issue(let metric):
                        IssueDetailView(metric: metric)
                    }
                }
        }
    }
}

// MARK: - Capture screen with AR overlay

private struct ScanCaptureScreen: View {
    var onScan: () -> Void

    var body: some View {
        ZStack {
            CameraPreview().ignoresSafeArea()
                .overlay(LinearGradient(colors: [.black.opacity(0.25), .clear, .black.opacity(0.35)],
                                        startPoint: .top, endPoint: .bottom).ignoresSafeArea())

            VStack {
                ClearMaxxWordmark(size: 24)
                    .colorMultiply(.white).brightness(0.4)
                    .padding(.top, 8)

                ZStack {
                    // Squircle reticle
                    RoundedRectangle(cornerRadius: 60, style: .continuous)
                        .stroke(CMGradient.aura, lineWidth: 3)
                        .frame(width: 260, height: 340)
                        .shadow(color: CMColor.violet.opacity(0.5), radius: 12)

                    // Floating hotspot labels
                    hotspot("Pores", color: CMColor.violet).offset(x: -90, y: -120)
                    hotspot("Hydration", color: CMColor.coral).offset(x: 80, y: -40)
                }

                lightingPill.padding(.top, 8)

                Spacer()

                HStack(spacing: 12) {
                    miniCard(title: "SKIN SCORE", value: "88", suffix: "/100")
                    miniCard(title: "ANALYSIS", value: "AI", suffix: "Optimizing…")
                }
                .padding(.horizontal, 20)

                // Capture button
                Button(action: onScan) {
                    ZStack {
                        Circle().fill(CMGradient.aura).frame(width: 74, height: 74)
                        Circle().stroke(.white, lineWidth: 4).frame(width: 74, height: 74)
                        Image(systemName: "camera.fill").font(.system(size: 26)).foregroundStyle(.white)
                    }
                    .shadow(color: CMColor.coral.opacity(0.5), radius: 14, y: 6)
                }
                .padding(.top, 14)
                .padding(.bottom, 90)   // clear the tab bar
            }
            .padding(.horizontal, 8)
        }
    }

    private func hotspot(_ text: String, color: Color) -> some View {
        Text(text.uppercased())
            .font(CMFont.inter(10, .bold)).tracking(1)
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(color, lineWidth: 1.5))
    }

    private var lightingPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "sun.max.fill").foregroundStyle(CMColor.coral)
            Text("Lighting: Perfect").font(CMFont.labelMd).foregroundStyle(CMColor.ink)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.white.opacity(0.9), in: Capsule())
        .bloomShadow()
    }

    private func miniCard(title: String, value: String, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            CategoryLabel(text: title)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(CMFont.inter(26, .heavy)).foregroundStyle(CMColor.ink)
                Text(suffix).font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .bloomShadow()
    }
}

// MARK: - AVFoundation front-camera preview

struct CameraPreview: UIViewRepresentable {
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        AVCaptureDevice.requestAccess(for: .video) { granted in
            guard granted else { return }
            DispatchQueue.global(qos: .userInitiated).async { view.configureSession() }
        }
        return view
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        private var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        private let session = AVCaptureSession()

        func configureSession() {
            session.beginConfiguration()
            session.sessionPreset = .high
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
               let input = try? AVCaptureDeviceInput(device: device),
               session.canAddInput(input) {
                session.addInput(input)
            }
            session.commitConfiguration()
            DispatchQueue.main.async {
                self.previewLayer.session = self.session
                self.previewLayer.videoGravity = .resizeAspectFill
            }
            session.startRunning()
        }
    }
}

#Preview { CameraScanView().environmentObject(AppState()) }

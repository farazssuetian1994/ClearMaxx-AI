//
//  CameraScanView.swift
//  ClearMaxx — Scan tab. Live front-camera preview with AR-style overlay + scan flow.
//

import SwiftUI
import UIKit
import AVFoundation
import PhotosUI

// MARK: - Scan flow routing

enum ScanRoute: Hashable { case analyzing, results, issue(SkinMetric) }

struct CameraScanView: View {
    @ObserveInjection var inject
    @EnvironmentObject var state: AppState
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScanCaptureScreen { image in
                state.pendingImage = image
                path.append(ScanRoute.analyzing)
            }
            .navigationDestination(for: ScanRoute.self) { route in
                switch route {
                case .analyzing:
                    AnalyzingView { path.append(ScanRoute.results) }
                case .results:
                    ResultsDashboardView(
                        onIssue: { path.append(ScanRoute.issue($0)) },
                        onRescan: { state.resetAnalysis(); path = NavigationPath() })
                case .issue(let metric):
                    IssueDetailView(metric: metric)
                }
            }
        }
    }
}

// MARK: - Capture screen with AR overlay

private struct ScanCaptureScreen: View {
    var onCapture: (UIImage) -> Void
    @StateObject private var camera = CameraController()
    @State private var photoItem: PhotosPickerItem?
    @State private var galleryFallback = false
    @State private var capturing = false
    @State private var pulse = false
    @State private var scan = false
    @State private var flashOn = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(session: camera.session).ignoresSafeArea()
            LinearGradient(colors: [.black.opacity(0.55), .clear, .clear, .black.opacity(0.8)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            faceGuide

            VStack(spacing: 0) {
                topBar
                Text("Hold still and look at the camera")
                    .font(CMFont.labelMd).foregroundStyle(.white.opacity(0.95))
                    .padding(.top, 8)
                Spacer()
                controls.padding(.bottom, 96)   // clear the floating tab bar
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .onAppear {
            camera.start()
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { scan = true }
        }
        .onDisappear { camera.stop() }
        .photosPicker(isPresented: $galleryFallback, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) { onCapture(image) }
            }
        }
    }

    // MARK: Top bar — close · "Good lighting" · flash
    private var topBar: some View {
        HStack {
            circleButton("xmark") { }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                Text("Good lighting").font(CMFont.labelSm)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(CMColor.success, in: Capsule())
            Spacer()
            circleButton(flashOn ? "bolt.fill" : "bolt.slash.fill") { flashOn.toggle() }
        }
    }

    private func circleButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.18), in: Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Oval face guide with a sweeping scan line + breathing pulse
    private var faceGuide: some View {
        ZStack {
            Rectangle()
                .fill(LinearGradient(colors: [.clear, CMColor.violet, CMColor.coral, .clear],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 250, height: 3)
                .shadow(color: CMColor.violet, radius: 10)
                .offset(y: scan ? 150 : -150)
                .frame(width: 250, height: 330)
                .mask(Ellipse().frame(width: 250, height: 330))   // keep the beam inside the oval

            Ellipse().stroke(.white.opacity(0.9), lineWidth: 3)
                .frame(width: 250, height: 330)

            // N/E/S/W tick marks
            ForEach(0..<4) { i in
                Capsule().fill(.white)
                    .frame(width: i % 2 == 0 ? 4 : 22, height: i % 2 == 0 ? 22 : 4)
                    .offset(x: i == 1 ? 125 : (i == 3 ? -125 : 0),
                            y: i == 0 ? -165 : (i == 2 ? 165 : 0))
            }
        }
        .scaleEffect(pulse ? 1.0 : 0.97)
    }

    // MARK: Bottom controls — gallery · shutter · flip
    private var controls: some View {
        HStack {
            // Gallery
            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 22, weight: .medium)).foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            Spacer()

            // Shutter (camera capture)
            Button(action: capture) {
                ZStack {
                    Circle().stroke(.white, lineWidth: 4).frame(width: 82, height: 82)
                    Circle().fill(.white).frame(width: 66, height: 66)
                    if capturing { ProgressView().tint(.black) }
                }
            }
            .buttonStyle(.plain)
            .disabled(capturing)

            Spacer()

            // Flip camera
            Button { camera.flip() } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(.white.opacity(0.18), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }

    private func capture() {
        capturing = true
        Task {
            let image = await camera.capture()
            capturing = false
            if let image {
                onCapture(image)
            } else {
                galleryFallback = true   // Simulator / no camera → use the photo library
            }
        }
    }
}

// MARK: - AVFoundation camera preview (driven by CameraController's session)

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

#Preview { CameraScanView().environmentObject(AppState()) }

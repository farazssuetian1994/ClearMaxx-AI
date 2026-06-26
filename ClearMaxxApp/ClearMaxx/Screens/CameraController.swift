//
//  CameraController.swift
//  ClearMaxx — AVFoundation session for the live scan: preview, flip, photo capture.
//

import AVFoundation
import UIKit

@MainActor
final class CameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "com.clearmaxx.camera.session")
    private var position: AVCaptureDevice.Position = .front

    /// True once a camera input is wired up (always false on the Simulator).
    @Published var isReady = false

    private var continuation: CheckedContinuation<UIImage?, Never>?

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted { Task { @MainActor in self.configure() } }
            }
        default:
            break   // denied/restricted → Simulator or no permission; gallery still works
        }
    }

    func stop() {
        queue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func flip() {
        position = (position == .front) ? .back : .front
        configure()
    }

    func capture() async -> UIImage? {
        guard isReady else { return nil }
        return await withCheckedContinuation { cont in
            self.continuation = cont
            let settings = AVCapturePhotoSettings()
            queue.async { [output] in output.capturePhoto(with: settings, delegate: self) }
        }
    }

    // MARK: - Session config (off the main thread)

    private func configure() {
        queue.async { [self] in
            session.beginConfiguration()
            session.sessionPreset = .photo
            session.inputs.forEach { session.removeInput($0) }

            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
               let input = try? AVCaptureDeviceInput(device: device),
               session.canAddInput(input) {
                session.addInput(input)
            }
            if session.outputs.isEmpty, session.canAddOutput(output) {
                session.addOutput(output)
            }
            session.commitConfiguration()
            if !session.isRunning { session.startRunning() }

            let ready = !session.inputs.isEmpty
            Task { @MainActor in self.isReady = ready }
        }
    }

    // MARK: - Capture delegate

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto,
                                 error: Error?) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        Task { @MainActor in
            self.continuation?.resume(returning: image)
            self.continuation = nil
        }
    }
}

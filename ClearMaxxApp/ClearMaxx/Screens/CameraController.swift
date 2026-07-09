//
//  CameraController.swift
//  ClearMaxx — AVFoundation session for the live scan: preview, flip, photo capture.
//

import AVFoundation
import UIKit
import Vision

@MainActor
final class CameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate,
                               AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "com.clearmaxx.camera.session")
    private let visionQueue = DispatchQueue(label: "com.clearmaxx.camera.vision", qos: .userInitiated)
    private var position: AVCaptureDevice.Position = .front

    /// True once a camera input is wired up (always false on the Simulator).
    @Published var isReady = false
    /// True while Vision detects a face in the live preview. Gates the shutter button.
    @Published var faceDetected = false

    /// Written only from `configure()` (on `queue`), read only from the Vision
    /// delegate callback (on `visionQueue`) — never touched from the main actor,
    /// so plain, unsynchronized access is safe here.
    nonisolated(unsafe) private var visionOrientation: CGImagePropertyOrientation = .leftMirrored

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
        faceDetected = false
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
        let position = self.position
        queue.async { [self] in
            session.beginConfiguration()
            session.sessionPreset = .photo
            session.inputs.forEach { session.removeInput($0) }

            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
               let input = try? AVCaptureDeviceInput(device: device),
               session.canAddInput(input) {
                session.addInput(input)
            }
            if !session.outputs.contains(output), session.canAddOutput(output) {
                session.addOutput(output)
            }
            if !session.outputs.contains(videoOutput), session.canAddOutput(videoOutput) {
                videoOutput.alwaysDiscardsLateVideoFrames = true
                videoOutput.setSampleBufferDelegate(self, queue: visionQueue)
                session.addOutput(videoOutput)
            }
            visionOrientation = position == .front ? .leftMirrored : .right
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

    // MARK: - Live face detection (throttled by AVFoundation's frame-drop behavior:
    // `alwaysDiscardsLateVideoFrames` + a serial delegate queue mean a slow Vision
    // pass on one frame simply causes the next few frames to be skipped, rather
    // than queuing up — no manual timer/throttle needed.)

    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                   didOutput sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: visionOrientation)
        let found: Bool
        do {
            try handler.perform([request])
            found = !(request.results ?? []).isEmpty
        } catch {
            found = false
        }
        Task { @MainActor in self.faceDetected = found }
    }
}

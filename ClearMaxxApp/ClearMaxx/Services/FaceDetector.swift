//
//  FaceDetector.swift
//  ClearMaxx — Vision-based face detection for static photos (gallery picks).
//

import UIKit
import Vision

enum FaceDetector {
    /// True if at least one face is detected in `image`.
    static func containsFace(_ image: UIImage) async -> Bool {
        guard let cgImage = image.cgImage else { return false }
        let orientation = image.imageOrientation.cgImagePropertyOrientation
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNDetectFaceRectanglesRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
                do {
                    try handler.perform([request])
                    continuation.resume(returning: !(request.results ?? []).isEmpty)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }
}

private extension UIImage.Orientation {
    var cgImagePropertyOrientation: CGImagePropertyOrientation {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}

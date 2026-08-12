//
//  ScanPhotoStore.swift
//  ClearMaxx — saves/loads each scan's photo as a JPEG in the app's Documents dir.
//

import UIKit

enum ScanPhotoStore {
    private static var directory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("ScanPhotos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Saves `image` as a JPEG and returns the filename (not full path) to store on a `ScanRecord`.
    static func save(_ image: UIImage) throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let fileName = "\(UUID().uuidString).jpg"
        try data.write(to: directory.appendingPathComponent(fileName))
        return fileName
    }

    static func load(_ fileName: String) -> UIImage? {
        UIImage(contentsOfFile: directory.appendingPathComponent(fileName).path)
    }
}

extension ScanPhotoStore {
    /// Loads a saved scan photo downscaled to `maxEdge` on its longest side —
    /// used by progress analysis to keep upload payloads (and Gemini's
    /// per-image tiling cost) small without touching the full-res original.
    static func downscaled(_ fileName: String, maxEdge: CGFloat) -> UIImage? {
        load(fileName)?.cm_resized(maxDimension: maxEdge)
    }
}

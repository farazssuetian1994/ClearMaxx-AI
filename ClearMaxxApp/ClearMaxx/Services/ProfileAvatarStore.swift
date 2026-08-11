//
//  ProfileAvatarStore.swift
//  ClearMaxx — saves/loads the user's chosen profile photo as a single JPEG
//  in the app's Documents dir (overwritten on each change, unlike per-scan photos).
//

import UIKit

enum ProfileAvatarStore {
    private static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("profile_avatar.jpg")
    }

    @discardableResult
    static func save(_ image: UIImage) -> Bool {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return false }
        return (try? data.write(to: fileURL)) != nil
    }

    static func load() -> UIImage? {
        UIImage(contentsOfFile: fileURL.path)
    }
}

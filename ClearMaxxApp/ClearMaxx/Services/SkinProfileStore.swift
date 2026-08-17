//
//  SkinProfileStore.swift
//  ClearMaxx — persists the onboarding quiz answers (skin type, goal, concerns)
//  so every scan/routine request can be personalized to what the user told us.
//

import Foundation

struct SkinProfile: Codable {
    var skinType: String?
    var goal: String?
    var concerns: [String] = []
}

enum SkinProfileStore {
    private static let key = "cm_skin_profile"

    static func save(_ profile: SkinProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> SkinProfile? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SkinProfile.self, from: data)
    }
}

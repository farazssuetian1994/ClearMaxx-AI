//
//  ProgressAnalysisService.swift
//  ClearMaxx — calls the backend to compare scan history and get a progress verdict + adapted routine.
//

import UIKit

/// User-facing progress-analysis errors, mirroring SkinAnalysisError's calm,
/// plain-language pattern — we never surface raw status codes to the user.
enum ProgressAnalysisError: LocalizedError {
    case encodingFailed
    case offline
    case timedOut
    case unauthorized
    case rateLimited
    case serverBusy
    case unknown

    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "We couldn't prepare your scan history. Please try again."
        case .offline:        return "You appear to be offline. Check your connection and try again."
        case .timedOut:       return "This is taking longer than usual. Please try again."
        case .unauthorized:   return "We couldn't start your progress check right now. Please update ClearMaxx or try again later."
        case .rateLimited:    return "A lot of progress checks are happening right now. Please try again in a moment."
        case .serverBusy:     return "Our progress analysis is taking a quick break. Please try again shortly."
        case .unknown:        return "Something went wrong while checking your progress. Please try again."
        }
    }
}

private struct ProgressResponseEnvelope: Codable {
    let success: Bool?
    let result: ProgressReport?
    let error: String?
}

enum ProgressAnalysisService {
    /// Images are capped smaller than the single-scan path (768px vs 1024px) —
    /// judging visual change across two photos needs far less detail than the
    /// primary per-scan analysis, and this call sends two images, not one.
    private static let maxImageEdge: CGFloat = 768

    static func analyze(trend: ProgressTrend, firstImage: UIImage?, latestImage: UIImage?,
                        currentRoutine: [APIRoutineStep]) async throws -> ProgressReport {
        var body: [String: Any] = [
            "span_days": trend.spanDays,
            "scan_count": trend.scanCount,
            "overall": [
                "first_score": trend.overallFirstScore,
                "latest_score": trend.overallLatestScore,
                "direction": trend.overallDirection.rawValue,
            ],
            "trends": trend.metricTrends.map {
                ["name": $0.name, "first_value": $0.firstValue,
                 "latest_value": $0.latestValue, "direction": $0.direction.rawValue]
            },
            "history": trend.sampledHistory.map {
                ["date": ISO8601DateFormatter().string(from: $0.date), "score": $0.clearScore]
            },
            "current_routine": currentRoutine.map {
                ["time": $0.time, "category": $0.category, "title": $0.title,
                 "detail": $0.detail, "tags": $0.tags]
            },
        ]
        if let firstImage, let jpeg = firstImage.cm_resized(maxDimension: maxImageEdge).jpegData(compressionQuality: 0.7) {
            body["first_image_base64"] = jpeg.base64EncodedString()
        }
        if let latestImage, let jpeg = latestImage.cm_resized(maxDimension: maxImageEdge).jpegData(compressionQuality: 0.7) {
            body["latest_image_base64"] = jpeg.base64EncodedString()
        }

        var req = URLRequest(url: CMConfig.backendURL.appendingPathComponent("api/skin/progress"))
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(CMConfig.appToken, forHTTPHeaderField: "X-App-Token")
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw ProgressAnalysisError.encodingFailed
        }

        let data: Data
        let resp: URLResponse
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch let e as URLError {
            switch e.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                throw ProgressAnalysisError.offline
            case .timedOut:
                throw ProgressAnalysisError.timedOut
            default:
                print("[ProgressAnalysis] network error: \(e.code.rawValue) \(e.localizedDescription)")
                throw ProgressAnalysisError.unknown
            }
        }

        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let decoded = try? JSONDecoder().decode(ProgressResponseEnvelope.self, from: data)

        guard status == 200, let result = decoded?.result else {
            print("[ProgressAnalysis] server \(status): \(decoded?.error ?? "no body")")
            switch status {
            case 401, 403:  throw ProgressAnalysisError.unauthorized
            case 429:       throw ProgressAnalysisError.rateLimited
            case 500...599: throw ProgressAnalysisError.serverBusy
            default:        throw ProgressAnalysisError.unknown
            }
        }
        return result
    }
}

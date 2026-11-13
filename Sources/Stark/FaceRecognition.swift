import CoreImage
import Foundation
import QuartzCore
import Vision

struct FaceFrameResult: Sendable {
    let featurePrintData: Data?
    let confidence: Float
    let hasFace: Bool
    let livenessScore: Double
    let isLive: Bool
}

enum FaceMatchState: Equatable {
    case notEnrolled
    case searching
    case matched(distance: Float)
    case rejected(distance: Float)
}

/// Runs on the camera queue. It returns only value types across the actor boundary.
/// Mutable state is confined to the serial camera queue.
final class FaceRecognitionService: @unchecked Sendable {
    private var recentCenters: [(time: CFTimeInterval, point: CGPoint)] = []
    private var frameIndex = 0
    private let livenessWindow: CFTimeInterval = 2.0
    private let motionThreshold = 0.035

    func reset() {
        recentCenters.removeAll()
        frameIndex = 0
    }

    func process(pixelBuffer: CVPixelBuffer, timestamp: CFTimeInterval = CACurrentMediaTime()) -> FaceFrameResult {
        let faceRequest = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        guard (try? handler.perform([faceRequest])) != nil,
              let face = faceRequest.results?.first as? VNFaceObservation else {
            return FaceFrameResult(featurePrintData: nil, confidence: 0, hasFace: false, livenessScore: 0, isLive: false)
        }

        let center = CGPoint(x: face.boundingBox.midX, y: face.boundingBox.midY)
        recentCenters.append((timestamp, center))
        recentCenters.removeAll { timestamp - $0.time > livenessWindow }

        let motion = totalMotion()
        let windowCoverage = recentCenters.last.map { _ in timestamp - recentCenters.first!.time } ?? 0
        let livenessScore = min(1, motion / 0.12) * min(1, windowCoverage / 0.65)
        let isLive = livenessScore >= motionThreshold / 0.12 && windowCoverage >= 0.65

        frameIndex += 1
        let printData = frameIndex % 6 == 0
            ? makeFeaturePrintData(pixelBuffer: pixelBuffer, boundingBox: face.boundingBox)
            : nil
        return FaceFrameResult(
            featurePrintData: printData,
            confidence: face.confidence,
            hasFace: true,
            livenessScore: livenessScore,
            isLive: isLive
        )
    }

    private func totalMotion() -> CGFloat {
        guard recentCenters.count > 1 else { return 0 }
        return zip(recentCenters, recentCenters.dropFirst()).reduce(0) { result, pair in
            result + hypot(pair.1.point.x - pair.0.point.x, pair.1.point.y - pair.0.point.y)
        }
    }

    private func makeFeaturePrintData(pixelBuffer: CVPixelBuffer, boundingBox: CGRect) -> Data? {
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let width = image.extent.width
        let height = image.extent.height
        let rawRect = CGRect(
            x: boundingBox.minX * width,
            y: boundingBox.minY * height,
            width: boundingBox.width * width,
            height: boundingBox.height * height
        )
        let padding = max(rawRect.width, rawRect.height) * 0.18
        let crop = rawRect.insetBy(dx: -padding, dy: -padding).intersection(image.extent)
        guard !crop.isEmpty else { return nil }

        let request = VNGenerateImageFeaturePrintRequest()
        let cropHandler = VNImageRequestHandler(ciImage: image.cropped(to: crop), options: [:])
        guard (try? cropHandler.perform([request])) != nil,
              let observation = request.results?.first as? VNFeaturePrintObservation else {
            return nil
        }

        return try? NSKeyedArchiver.archivedData(withRootObject: observation, requiringSecureCoding: true)
    }
}

enum FaceMatcher {
    static let matchThreshold: Float = 0.62

    static func distance(current: Data, enrolled: Data) -> Float? {
        guard let currentObservation = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: VNFeaturePrintObservation.self,
            from: current
        ),
        let enrolledObservation = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: VNFeaturePrintObservation.self,
            from: enrolled
        ) else {
            return nil
        }

        var distance: Float = 0
        guard (try? currentObservation.computeDistance(&distance, to: enrolledObservation)) != nil else {
            return nil
        }
        return distance
    }
}

enum StarkMatchPolicy {
    static func accepts(distance: Float, livenessScore: Double, confidence: Float) -> Bool {
        distance <= FaceMatcher.matchThreshold && livenessScore >= 0.30 && confidence >= 0.50
    }
}

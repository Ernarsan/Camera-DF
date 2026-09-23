import Foundation
import CoreImage
import Vision

public struct AlignmentGuidance: Sendable {
    public let targetPoint: CGPoint
    public let currentSubjectPoint: CGPoint?
    public let distance: CGFloat
    public let isAligned: Bool
    public let instruction: String
}

public class AlignmentGuide {

    // Fixed classic photography upper-third focal point (normalized, Vision bottom-left origin)
    // x: 0.5 (center), y: 0.67 (upper third)
    private static let targetPoint = CGPoint(x: 0.5, y: 0.67)
    // Forgiving threshold (~8.5% of frame) for comfortable handheld alignment
    private static let threshold: CGFloat = 0.085

    /// Evaluates a pixel buffer synchronously for faces, humans, or salient objects,
    /// providing real-time directional feedback to guide the photographer.
    public static func evaluate(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation = .up
    ) -> AlignmentGuidance {
        // Single handler — Vision reuses the internal pixel buffer across all requests
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])

        // Create all requests upfront
        let faceRequest = VNDetectFaceRectanglesRequest()
        let humanRequest = VNDetectHumanRectanglesRequest()
        let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()

        // Single perform() call — eliminates 3× handler creation overhead
        guard let _ = try? handler.perform([faceRequest, humanRequest, saliencyRequest]) else {
            return AlignmentGuidance(
                targetPoint: targetPoint,
                currentSubjectPoint: nil,
                distance: .infinity,
                isAligned: false,
                instruction: "Aim at subject to align composition"
            )
        }

        // Step 1: Try Face Detection (highest priority)
        if let faces = faceRequest.results, !faces.isEmpty {
            // Find the largest face to avoid jumping between multiple faces
            let largestFace = faces.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height })!
            let faceCenter = CGPoint(
                x: largestFace.boundingBox.midX,
                y: largestFace.boundingBox.midY
            )
            return processSubjectPoint(faceCenter)
        }

        // Step 2: Fallback to Human Detection
        if let humans = humanRequest.results, !humans.isEmpty {
            let largestHuman = humans.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height })!
            let box = largestHuman.boundingBox
            let upperY = box.minY + (box.height * 0.85) // Head approximation
            let headCenter = CGPoint(x: box.midX, y: upperY)
            return processSubjectPoint(headCenter)
        }

        // Step 3: Fallback to Neural Attention Saliency (for non-human objects, pets, food)
        if let saliency = saliencyRequest.results?.first,
           let objects = saliency.salientObjects, !objects.isEmpty {
            let largestObject = objects.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height })!
            let center = CGPoint(x: largestObject.boundingBox.midX, y: largestObject.boundingBox.midY)
            return processSubjectPoint(center)
        }

        // Step 4: No subject in frame
        return AlignmentGuidance(
            targetPoint: targetPoint,
            currentSubjectPoint: nil,
            distance: .infinity,
            isAligned: false,
            instruction: "Aim at subject to align composition"
        )
    }

    private static func processSubjectPoint(_ point: CGPoint) -> AlignmentGuidance {
        let dx = point.x - targetPoint.x
        let dy = point.y - targetPoint.y
        let aspect: CGFloat = 16.0 / 9.0
        let distance = sqrt(dx * dx + (dy * aspect) * (dy * aspect))

        let isAligned = distance < threshold

        let instruction: String
        if isAligned {
            instruction = "✦ Perfect Composition ✦"
        } else {
            // Intelligent directional coaching
            if abs(dx) > abs(dy) {
                if dx > 0 {
                    instruction = "Move right →"
                } else {
                    instruction = "← Move left"
                }
            } else {
                if dy > 0 {
                    instruction = "Move up ↑"
                } else {
                    instruction = "↓ Move down"
                }
            }
        }

        return AlignmentGuidance(
            targetPoint: targetPoint,
            currentSubjectPoint: point,
            distance: distance,
            isAligned: isAligned,
            instruction: instruction
        )
    }
}

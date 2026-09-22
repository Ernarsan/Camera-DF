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
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])

        // Step 1: Try Face Detection
        let faceRequest = VNDetectFaceRectanglesRequest()
        if let _ = try? handler.perform([faceRequest]),
           let faces = faceRequest.results,
           let firstFace = faces.first {
            let faceCenter = CGPoint(
                x: firstFace.boundingBox.midX,
                y: firstFace.boundingBox.midY
            )
            return processSubjectPoint(faceCenter)
        }

        // Step 2: Fallback to Human Detection
        let humanRequest = VNDetectHumanRectanglesRequest()
        if let _ = try? handler.perform([humanRequest]),
           let humans = humanRequest.results,
           let firstHuman = humans.first {
            let box = firstHuman.boundingBox
            let upperY = box.minY + (box.height * 0.85) // Head approximation
            let headCenter = CGPoint(x: box.midX, y: upperY)
            return processSubjectPoint(headCenter)
        }

        // Step 3: Fallback to Neural Attention Saliency (for non-human objects, pets, food)
        let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()
        if let _ = try? handler.perform([saliencyRequest]),
           let saliency = saliencyRequest.results?.first,
           let object = saliency.salientObjects?.first {
            let center = CGPoint(x: object.boundingBox.midX, y: object.boundingBox.midY)
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
        let distance = sqrt(dx * dx + dy * dy)

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

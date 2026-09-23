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

    // Forgiving threshold (~8.5% of frame) for comfortable handheld alignment
    private static let threshold: CGFloat = 0.085

    /// Evaluates a pixel buffer synchronously using advanced photographic rules
    /// (Rule of Thirds, Looking Room, Center of Gravity) to provide intelligent composition.
    public static func evaluate(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation = .up
    ) -> AlignmentGuidance {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        let faceRequest = VNDetectFaceRectanglesRequest()
        let humanRequest = VNDetectHumanRectanglesRequest()
        let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()

        guard let _ = try? handler.perform([faceRequest, humanRequest, saliencyRequest]) else {
            return processSubjectPoint(nil, target: CGPoint(x: 0.5, y: 0.5))
        }

        // --- 1. FACE DETECTION (Highest Priority: Portraits & Groups) ---
        if let faces = faceRequest.results as? [VNFaceObservation], !faces.isEmpty {
            if faces.count == 1, let face = faces.first {
                // Solo Portrait: Apply "Looking Room" (Rule of Thirds)
                let box = face.boundingBox
                let faceCenter = CGPoint(x: box.midX, y: box.midY)
                
                // Default to upper-third center
                var targetX: CGFloat = 0.5
                let targetY: CGFloat = 0.67 // Eyes on upper third
                
                // If the person is looking significantly to a side, place them on the opposite third
                if let yaw = face.yaw {
                    let yawValue = CGFloat(truncating: yaw)
                    if yawValue < -0.3 { // Looking left (from camera perspective)
                        targetX = 0.67 // Place person on right third (lead room)
                    } else if yawValue > 0.3 { // Looking right
                        targetX = 0.33 // Place person on left third
                    }
                }
                
                return processSubjectPoint(faceCenter, target: CGPoint(x: targetX, y: targetY))
            } else {
                // Group Portrait: Center of gravity of all faces
                let sumX = faces.reduce(0.0) { $0 + $1.boundingBox.midX }
                let sumY = faces.reduce(0.0) { $0 + $1.boundingBox.midY }
                let centerOfGravity = CGPoint(x: sumX / CGFloat(faces.count), y: sumY / CGFloat(faces.count))
                
                // Suggest centering the group
                return processSubjectPoint(centerOfGravity, target: CGPoint(x: 0.5, y: 0.6))
            }
        }

        // --- 2. HUMAN BODY DETECTION ---
        if let humans = humanRequest.results, !humans.isEmpty {
            // Find largest human (foreground subject)
            let largestHuman = humans.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height })!
            let box = largestHuman.boundingBox
            // Suggest giving proper headroom (place head on upper third)
            let headCenter = CGPoint(x: box.midX, y: box.minY + (box.height * 0.85))
            return processSubjectPoint(headCenter, target: CGPoint(x: 0.5, y: 0.67))
        }

        // --- 3. NEURAL SALIENCY (Objects, Architecture, Food) ---
        if let saliency = saliencyRequest.results?.first,
           let objects = saliency.salientObjects, !objects.isEmpty {
            let largestObject = objects.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height })!
            let center = CGPoint(x: largestObject.boundingBox.midX, y: largestObject.boundingBox.midY)
            
            // For objects, place on golden ratio intersection or center
            let isLandscape = CVPixelBufferGetWidth(pixelBuffer) > CVPixelBufferGetHeight(pixelBuffer)
            let target = isLandscape ? CGPoint(x: 0.382, y: 0.382) : CGPoint(x: 0.5, y: 0.5)
            return processSubjectPoint(center, target: target)
        }

        // --- 4. NO SUBJECT (Fallback) ---
        return processSubjectPoint(nil, target: CGPoint(x: 0.5, y: 0.5))
    }

    private static func processSubjectPoint(_ point: CGPoint?, target: CGPoint) -> AlignmentGuidance {
        guard let point = point else {
            return AlignmentGuidance(
                targetPoint: target,
                currentSubjectPoint: nil,
                distance: .infinity,
                isAligned: false,
                instruction: "Explore scene for AI framing"
            )
        }

        let dx = point.x - target.x
        let dy = point.y - target.y
        let aspect: CGFloat = 16.0 / 9.0 // Scale Y to fix elliptical distance
        let distance = sqrt(dx * dx + (dy * aspect) * (dy * aspect))

        let isAligned = distance < threshold

        let instruction: String
        if isAligned {
            instruction = "✨ Cinematic Frame ✨"
        } else {
            // Smart directional coaching based on offset
            if abs(dx) > abs(dy) {
                instruction = dx > 0 ? "Pan Right ➡" : "⬅ Pan Left"
            } else {
                instruction = dy > 0 ? "Tilt Up ⬆" : "⬇ Tilt Down"
            }
        }

        return AlignmentGuidance(
            targetPoint: target,
            currentSubjectPoint: point,
            distance: distance,
            isAligned: isAligned,
            instruction: instruction
        )
    }
}

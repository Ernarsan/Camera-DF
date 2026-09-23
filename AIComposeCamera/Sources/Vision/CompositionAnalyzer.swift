import Vision
import CoreImage
import Foundation

public enum AISubjectType: String, Sendable {
    case face = "Face"
    case person = "Person"
    case object = "Object"
    case none = "None"
}

public struct CompositionResult: Sendable {
    public let saliencyBox: CGRect?      // normalized Vision coordinates (origin bottom-left, 0...1)
    public let suggestedZoom: CGFloat?   // 1x / 2x / 4x / 6x
    public let subjectType: AISubjectType
}

public struct CompositionAnalyzer {

    /// Multi-tier AI subject detection:
    /// 1. Face detection (highest priority for portraits & selfies)
    /// 2. Human body detection (for full-body and group shots)
    /// 3. Neural attention saliency (for objects, food, pets, architecture)
    public static func analyze(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation = .up
    ) -> CompositionResult {
        // Single handler — Vision reuses the internal pixel buffer across all requests
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])

        // Create all requests upfront
        let faceRequest = VNDetectFaceRectanglesRequest()
        let humanRequest = VNDetectHumanRectanglesRequest()
        let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()

        // Single perform() call — eliminates 3× handler creation overhead
        guard let _ = try? handler.perform([faceRequest, humanRequest, saliencyRequest]) else {
            return CompositionResult(saliencyBox: nil, suggestedZoom: nil, subjectType: .none)
        }

        // Tier 1: Face Detection (highest priority)
        if let faces = faceRequest.results,
           let primaryFace = faces.first {

            // Expand face box slightly for natural portrait framing
            let box = primaryFace.boundingBox
            let padX = box.width * 0.2
            let padY = box.height * 0.3
            let expandedBox = CGRect(
                x: max(0, box.minX - padX),
                y: max(0, box.minY - padY * 0.5),
                width: min(1 - max(0, box.minX - padX), box.width + padX * 2),
                height: min(1 - max(0, box.minY - padY * 0.5), box.height + padY * 1.5)
            )

            let area = expandedBox.width * expandedBox.height
            let zoom = calculateSuggestedZoom(forArea: area)
            return CompositionResult(saliencyBox: expandedBox, suggestedZoom: zoom, subjectType: .face)
        }

        // Tier 2: Human Body Detection
        if let humans = humanRequest.results,
           let primaryHuman = humans.first {

            let box = primaryHuman.boundingBox
            let area = box.width * box.height
            let zoom = calculateSuggestedZoom(forArea: area)
            return CompositionResult(saliencyBox: box, suggestedZoom: zoom, subjectType: .person)
        }

        // Tier 3: Neural Attention Saliency
        if let results = saliencyRequest.results,
           let firstResult = results.first,
           let salientObjects = firstResult.salientObjects,
           let bestObject = salientObjects.first {

            let box = bestObject.boundingBox
            let area = box.width * box.height
            let zoom = calculateSuggestedZoom(forArea: area)
            return CompositionResult(saliencyBox: box, suggestedZoom: zoom, subjectType: .object)
        }

        return CompositionResult(saliencyBox: nil, suggestedZoom: nil, subjectType: .none)
    }

    private static func calculateSuggestedZoom(forArea area: CGFloat) -> CGFloat {
        if area < 0.04 {
            return 4.0
        } else if area < 0.12 {
            return 2.0
        } else if area < 0.25 {
            return 1.5
        } else {
            return 1.0
        }
    }
}

import Vision
import CoreImage
import Foundation

public enum AISubjectType: String, Sendable {
    case face = "Portrait"
    case group = "Group"
    case person = "Person"
    case object = "Object"
    case none = "None"
}

public struct CompositionResult: Sendable {
    public let saliencyBox: CGRect?      // normalized Vision coordinates (origin bottom-left, 0...1)
    public let suggestedZoom: CGFloat?   // 0.5x / 1x / 2x / 4x
    public let subjectType: AISubjectType
    public let framingTip: String?
}

/// AI Composition and Saliency Analyzer incorporating Subject-Aware Composition Network (SAC-Net)
/// and Google Framing Hints heuristics.
public struct CompositionAnalyzer {

    /// Multi-tier AI subject detection:
    /// 1. Face detection (highest priority for portraits & selfies)
    /// 2. Human body detection (for full-body and group shots)
    /// 3. Neural attention saliency (for objects, food, pets, architecture)
    public static func analyze(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation = .up
    ) -> CompositionResult {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        let faceRequest = VNDetectFaceRectanglesRequest()
        let humanRequest = VNDetectHumanRectanglesRequest()
        let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()

        guard let _ = try? handler.perform([faceRequest, humanRequest, saliencyRequest]) else {
            return CompositionResult(saliencyBox: nil, suggestedZoom: nil, subjectType: .none, framingTip: nil)
        }

        // Tier 1: Face Detection (highest priority)
        if let faces = faceRequest.results, !faces.isEmpty {
            if faces.count == 1, let primaryFace = faces.first {
                let box = primaryFace.boundingBox
                let padX = box.width * 0.4
                let padY = box.height * 0.6
                
                var shiftX: CGFloat = 0
                if let obs = primaryFace as? VNFaceObservation, let yaw = obs.yaw {
                    let yawValue = CGFloat(truncating: yaw)
                    shiftX = yawValue * box.width * 0.5
                }
                
                let expandedBox = CGRect(
                    x: max(0, box.minX - padX * 0.5 + shiftX),
                    y: max(0, box.minY - padY * 0.7),
                    width: min(1, box.width + padX),
                    height: min(1, box.height + padY)
                )

                let area = box.width * box.height
                let zoom = calculateSuggestedZoom(forArea: area, type: .face)
                let tip = (area > 0.07) ? "Рекомендуется 2x (устранение дисторсии лица)" : "Портретный фокус (Rule of Thirds)"
                return CompositionResult(saliencyBox: expandedBox, suggestedZoom: zoom, subjectType: .face, framingTip: tip)
            } else {
                // Group Shot: Create a union of all face bounding boxes
                var groupBox = faces.first!.boundingBox
                for face in faces {
                    groupBox = groupBox.union(face.boundingBox)
                }
                
                let padX = groupBox.width * 0.2
                let padY = groupBox.height * 0.4
                let expandedGroup = CGRect(
                    x: max(0, groupBox.minX - padX),
                    y: max(0, groupBox.minY - padY * 0.5),
                    width: min(1, groupBox.width + padX * 2),
                    height: min(1, groupBox.height + padY * 1.5)
                )
                
                let area = expandedGroup.width * expandedGroup.height
                let zoom = calculateSuggestedZoom(forArea: area, type: .group)
                let tip = (area > 0.4) ? "Используйте 0.5x для широкого угла группы" : "Групповая компоновка по центру"
                return CompositionResult(saliencyBox: expandedGroup, suggestedZoom: zoom, subjectType: .group, framingTip: tip)
            }
        }

        // Tier 2: Human Body Detection
        if let humans = humanRequest.results, !humans.isEmpty {
            let primaryHuman = humans.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height })!
            let box = primaryHuman.boundingBox
            let area = box.width * box.height
            let zoom = calculateSuggestedZoom(forArea: area, type: .person)
            let tip = (box.height > 0.5) ? "Съемка с уровня пояса (пропорции ног)" : "Поясной ракурс (уровень груди)"
            return CompositionResult(saliencyBox: box, suggestedZoom: zoom, subjectType: .person, framingTip: tip)
        }

        // Tier 3: Neural Attention Saliency
        if let results = saliencyRequest.results,
           let firstResult = results.first,
           let salientObjects = firstResult.salientObjects, !salientObjects.isEmpty {
            let bestObject = salientObjects.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height })!
            let box = bestObject.boundingBox
            let area = box.width * box.height
            let zoom = calculateSuggestedZoom(forArea: area, type: .object)
            let tip = (area < 0.04) ? "Макро-съемка деталей" : "Золотое сечение объекта"
            return CompositionResult(saliencyBox: box, suggestedZoom: zoom, subjectType: .object, framingTip: tip)
        }

        return CompositionResult(saliencyBox: nil, suggestedZoom: nil, subjectType: .none, framingTip: nil)
    }

    private static func calculateSuggestedZoom(forArea area: CGFloat, type: AISubjectType) -> CGFloat {
        switch type {
        case .face:
            // Anti-distortion logic from mobile photography research:
            // Wide-angle (24mm) causes bulbous distortion when face is close -> switch to 2x (50mm equivalent)
            if area > 0.08 { return 2.0 }
            if area < 0.04 { return 2.0 }
            return 1.0
        case .person:
            if area < 0.08 { return 2.0 }
            return 1.0
        case .group:
            // Large groups need ultra-wide lens to prevent edge clipping
            if area > 0.4 { return 0.5 }
            return 1.0
        case .object, .none:
            if area < 0.02 { return 2.0 }
            if area < 0.06 { return 2.0 }
            return 1.0
        }
    }
}

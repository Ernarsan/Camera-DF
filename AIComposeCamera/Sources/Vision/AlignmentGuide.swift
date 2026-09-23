import Foundation
import CoreImage
import Vision
import CoreGraphics

public struct AlignmentGuidance: Sendable {
    public let targetPoint: CGPoint
    public let currentSubjectPoint: CGPoint?
    public let distance: CGFloat
    public let isAligned: Bool
    public let instruction: String
    public let coachingTip: String?
    public let suggestedZoom: CGFloat?
}

/// Intelligent Framing & Angle Assistant inspired by:
/// - Samsung Shot Suggestions & Single Take (Target rings, golden alignment)
/// - Google Pixel Framing Hints & Guided Frame (Horizon, distance, lens suggestions)
/// - GudoCam / SAC-Net (Optical axis height rules, waist/eye-level framing, 14 math schemes)
/// - Posei AI / SOVS2 (Peripheral safety margins, proportion preservation)
public class AlignmentGuide {

    // Threshold (~8.5% of frame) for comfortable handheld alignment (Samsung Shot Suggestions style)
    private static let threshold: CGFloat = 0.085

    /// Evaluates a pixel buffer synchronously using advanced photographic rules
    /// from mobile AI research:
    /// - Optical axis height rules (Eye level, Waist/Chest level for full body)
    /// - Looking room / Lead room (yaw vector) with Golden Ratio (0.382 / 0.618)
    /// - Anti-distortion lens advisory (recommending 2x for close portraits)
    /// - Peripheral boundary alerts (preventing cut limbs/joints)
    public static func evaluate(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation = .up
    ) -> AlignmentGuidance {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        let faceRequest = VNDetectFaceRectanglesRequest()
        let humanRequest = VNDetectHumanRectanglesRequest()
        let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()

        guard let _ = try? handler.perform([faceRequest, humanRequest, saliencyRequest]) else {
            return processSubjectPoint(nil, target: CGPoint(x: 0.5, y: 0.5), tip: nil, zoom: nil)
        }

        // --- 1. FACE DETECTION (High Priority: Portraits & Groups) ---
        if let faces = faceRequest.results as? [VNFaceObservation], !faces.isEmpty {
            if faces.count == 1, let face = faces.first {
                let box = face.boundingBox
                let faceCenter = CGPoint(x: box.midX, y: box.midY)
                
                // Peripheral Alert Check: Is face too close to borders? (Peripheral Alerts)
                let isPeripheralRisk = box.minX < 0.04 || box.maxX > 0.96 || box.maxY > 0.96
                
                // Anti-distortion check: Face occupying > 10% of frame on wide lens (24mm distortion)
                let isFaceTooClose = (box.width * box.height) > 0.07
                
                // Default golden ratio placement: upper third (eyes at ~0.618)
                var targetX: CGFloat = 0.5
                let targetY: CGFloat = 0.618 // Golden Ratio upper horizontal node
                
                // Looking room analysis using face yaw angle
                var tip: String? = nil
                if let yaw = face.yaw {
                    let yawValue = CGFloat(truncating: yaw)
                    if yawValue < -0.22 { // Looking left
                        targetX = 0.618 // Place subject on right golden section (lead space on left)
                        tip = "Золотое сечение: взгляд в кадр"
                    } else if yawValue > 0.22 { // Looking right
                        targetX = 0.382 // Place subject on left golden section
                        tip = "Золотое сечение: взгляд в кадр"
                    }
                }
                
                if isPeripheralRisk {
                    tip = "⚠ Отодвиньте камеру (обрезка по краям)"
                } else if isFaceTooClose && tip == nil {
                    tip = "Используйте 2x (устранение дисторсии лица)"
                } else if tip == nil {
                    tip = "Уровень глаз: естественные пропорции лица"
                }
                
                let suggestedZoom: CGFloat? = isFaceTooClose ? 2.0 : nil
                return processSubjectPoint(faceCenter, target: CGPoint(x: targetX, y: targetY), tip: tip, zoom: suggestedZoom)
            } else {
                // Group Portrait: Center of visual mass with headroom
                let sumX = faces.reduce(0.0) { $0 + $1.boundingBox.midX }
                let sumY = faces.reduce(0.0) { $0 + $1.boundingBox.midY }
                let centerOfGravity = CGPoint(x: sumX / CGFloat(faces.count), y: sumY / CGFloat(faces.count))
                
                let tip = "Групповой снимок: центрирование и запас сверху"
                return processSubjectPoint(centerOfGravity, target: CGPoint(x: 0.5, y: 0.618), tip: tip, zoom: nil)
            }
        }

        // --- 2. HUMAN BODY DETECTION (Full-body & Bust Portraits) ---
        if let humans = humanRequest.results, !humans.isEmpty {
            let largestHuman = humans.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height })!
            let box = largestHuman.boundingBox
            
            // Peripheral Alert
            let isPeripheral = box.minX < 0.03 || box.maxX > 0.97 || box.minY < 0.03
            
            if box.height > 0.45 {
                // Full-body portrait: Optical axis rule from article:
                // "Уровень груди / талии — сохранение соосности вертикальных линий, предотвращение укорачивания ног"
                let chestCenter = CGPoint(x: box.midX, y: box.minY + (box.height * 0.55))
                let tip = isPeripheral ? "⚠ Отодвиньте камеру (обрезка суставов)" : "Уровень талии: правильные пропорции ног"
                return processSubjectPoint(chestCenter, target: CGPoint(x: 0.5, y: 0.5), tip: tip, zoom: nil)
            } else {
                // Medium / Bust portrait: Eye-level alignment
                let headCenter = CGPoint(x: box.midX, y: box.minY + (box.height * 0.8))
                let tip = isPeripheral ? "⚠ Внимание к границам кадра" : "Правило третей: запас над головой"
                return processSubjectPoint(headCenter, target: CGPoint(x: 0.5, y: 0.618), tip: tip, zoom: nil)
            }
        }

        // --- 3. NEURAL ATTENTION SALIENCY (Objects, Architecture, Food, Macro) ---
        if let saliency = saliencyRequest.results?.first,
           let objects = saliency.salientObjects, !objects.isEmpty {
            let largestObject = objects.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height })!
            let box = largestObject.boundingBox
            let center = CGPoint(x: box.midX, y: box.midY)
            
            let isMacro = (box.width * box.height) < 0.04
            let isLandscape = CVPixelBufferGetWidth(pixelBuffer) > CVPixelBufferGetHeight(pixelBuffer)
            
            let target = isLandscape ? CGPoint(x: 0.382, y: 0.382) : CGPoint(x: 0.5, y: 0.5)
            let tip = isMacro ? "Макро / Детали: центрирование объекта" : "Золотое сечение (Samsung Shot Suggestions)"
            
            return processSubjectPoint(center, target: target, tip: tip, zoom: isMacro ? 2.0 : nil)
        }

        // --- 4. FALLBACK ---
        return processSubjectPoint(nil, target: CGPoint(x: 0.5, y: 0.5), tip: "Поиск композиционного центра...", zoom: nil)
    }

    private static func processSubjectPoint(_ point: CGPoint?, target: CGPoint, tip: String?, zoom: CGFloat?) -> AlignmentGuidance {
        guard let point = point else {
            return AlignmentGuidance(
                targetPoint: target,
                currentSubjectPoint: nil,
                distance: .infinity,
                isAligned: false,
                instruction: "Наведите на объект для авто-ракурса",
                coachingTip: tip,
                suggestedZoom: zoom
            )
        }

        let dx = point.x - target.x
        let dy = point.y - target.y
        let aspect: CGFloat = 16.0 / 9.0
        let distance = sqrt(dx * dx + (dy * aspect) * (dy * aspect))

        let isAligned = distance < threshold

        let instruction: String
        if isAligned {
            instruction = "Perfect Composition"
        } else {
            instruction = "Move your phone to align the composition point"
        }

        return AlignmentGuidance(
            targetPoint: target,
            currentSubjectPoint: point,
            distance: distance,
            isAligned: isAligned,
            instruction: instruction,
            coachingTip: tip,
            suggestedZoom: zoom
        )
    }
}

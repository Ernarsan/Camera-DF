import Foundation
import CoreImage
import Vision

public struct AlignmentGuidance {
    public let targetPoint: CGPoint
    public let currentSubjectPoint: CGPoint?
    public let distance: CGFloat
    public let isAligned: Bool
    public let instruction: String
}

public class AlignmentGuide {
    
    // Fixed target point (normalized, Vision uses bottom-left origin)
    // x: 0.5 (center), y: 0.67 (upper third)
    private static let targetPoint = CGPoint(x: 0.5, y: 0.67)
    private static let threshold: CGFloat = 0.04 * sqrt(2.0)
    
    private static let requestQueue = DispatchQueue(label: "com.aicomposecamera.vision.alignmentguide", qos: .userInitiated)
    
    public static func evaluate(ciImage: CIImage, completion: @escaping (AlignmentGuidance) -> Void) {
        requestQueue.async {
            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            
            // Step 1: Try Face Detection
            let faceRequest = VNDetectFaceRectanglesRequest()
            
            do {
                try handler.perform([faceRequest])
                
                if let results = faceRequest.results, let firstFace = results.first {
                    let faceCenter = CGPoint(
                        x: firstFace.boundingBox.midX,
                        y: firstFace.boundingBox.midY
                    )
                    processSubjectPoint(faceCenter, completion: completion)
                    return
                }
            } catch {
                print("Face detection failed: \(error)")
            }
            
            // Step 2: Fallback to Human Detection
            let humanRequest = VNDetectHumanRectanglesRequest()
            
            do {
                try handler.perform([humanRequest])
                
                if let results = humanRequest.results, let firstHuman = results.first {
                    let humanBoundingBox = firstHuman.boundingBox
                    // Center of top 30% of bbox as approximation for head
                    // Vision origin is bottom-left, so higher Y is towards the top
                    let upperY = humanBoundingBox.minY + (humanBoundingBox.height * 0.85)
                    
                    let headCenter = CGPoint(
                        x: humanBoundingBox.midX,
                        y: upperY
                    )
                    processSubjectPoint(headCenter, completion: completion)
                    return
                }
            } catch {
                print("Human detection failed: \(error)")
            }
            
            // Step 3: Nothing found
            let guidance = AlignmentGuidance(
                targetPoint: targetPoint,
                currentSubjectPoint: nil,
                distance: .infinity,
                isAligned: false,
                instruction: "Ai Detecting the scene. Keep your phone still."
            )
            completion(guidance)
        }
    }
    
    private static func processSubjectPoint(_ point: CGPoint, completion: @escaping (AlignmentGuidance) -> Void) {
        let dx = point.x - targetPoint.x
        let dy = point.y - targetPoint.y
        let distance = sqrt(dx * dx + dy * dy)
        
        let isAligned = distance < threshold
        
        let instruction: String
        if isAligned {
            instruction = "Perfect Composition"
        } else {
            instruction = "Move your phone to align the composition point"
        }
        
        let guidance = AlignmentGuidance(
            targetPoint: targetPoint,
            currentSubjectPoint: point,
            distance: distance,
            isAligned: isAligned,
            instruction: instruction
        )
        completion(guidance)
    }
}

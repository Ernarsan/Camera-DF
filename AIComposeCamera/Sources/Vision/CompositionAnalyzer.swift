import Vision
import CoreImage
import Foundation

struct CompositionResult {
    let saliencyBox: CGRect?      // normalized Vision coordinates (origin bottom-left, 0...1)
    let suggestedZoom: CGFloat?   // 1x / 2x / 4x / 6x
}

struct CompositionAnalyzer {
    
    private static let analysisQueue = DispatchQueue(label: "com.aicomposecamera.saliency", qos: .userInitiated)
    
    static func analyze(ciImage: CIImage, completion: @escaping (CompositionResult) -> Void) {
        analysisQueue.async {
            let request = VNGenerateAttentionBasedSaliencyImageRequest()
            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            
            do {
                try handler.perform([request])
                
                guard let results = request.results as? [VNSaliencyImageObservation],
                      let firstResult = results.first,
                      let salientObjects = firstResult.salientObjects,
                      let bestObject = salientObjects.first else {
                    completion(CompositionResult(saliencyBox: nil, suggestedZoom: nil))
                    return
                }
                
                let boundingBox = bestObject.boundingBox
                let area = boundingBox.width * boundingBox.height
                
                let suggestedZoom: CGFloat
                if area < 0.05 {
                    suggestedZoom = 6.0
                } else if area < 0.12 {
                    suggestedZoom = 4.0
                } else if area < 0.25 {
                    suggestedZoom = 2.0
                } else {
                    suggestedZoom = 1.0
                }
                
                let result = CompositionResult(saliencyBox: boundingBox, suggestedZoom: suggestedZoom)
                completion(result)
                
            } catch {
                completion(CompositionResult(saliencyBox: nil, suggestedZoom: nil))
            }
        }
    }
}

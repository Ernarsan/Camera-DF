import Vision
import CoreImage
import Foundation

struct CompositionResult: Sendable {
    let saliencyBox: CGRect?      // normalized Vision coordinates (origin bottom-left, 0...1)
    let suggestedZoom: CGFloat?   // 1x / 2x / 4x / 6x
}

struct CompositionAnalyzer {

    /// Analyzes a pixel buffer synchronously for salient objects and optimal composition framing.
    /// Runs directly on the caller's queue (e.g. background analysis queue) while the buffer is valid.
    static func analyze(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation = .up) -> CompositionResult {
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])

        do {
            try handler.perform([request])

            guard let results = request.results,
                  let firstResult = results.first,
                  let salientObjects = firstResult.salientObjects,
                  let bestObject = salientObjects.first else {
                return CompositionResult(saliencyBox: nil, suggestedZoom: nil)
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

            return CompositionResult(saliencyBox: boundingBox, suggestedZoom: suggestedZoom)
        } catch {
            return CompositionResult(saliencyBox: nil, suggestedZoom: nil)
        }
    }
}

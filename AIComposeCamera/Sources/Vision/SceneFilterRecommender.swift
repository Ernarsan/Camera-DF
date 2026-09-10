import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Represents a scene filter recommendation based on image analysis.
struct SceneRecommendation {
    let sceneDescription: String
    let filterName: String
    let reason: String
}

/// Analyzes scene brightness and color temperature to recommend a CIFilter.
class SceneFilterRecommender {
    /// Serial queue to protect mutable `lastFilterType` state.
    private static let stateQueue = DispatchQueue(label: "com.aicompose.scenefilter.state")
    private static var _lastFilterType: FilterType = .natural

    private static var lastFilterType: FilterType {
        get { stateQueue.sync { _lastFilterType } }
        set { stateQueue.sync { _lastFilterType = newValue } }
    }
    
    private enum FilterType {
        case cool
        case warm
        case night
        case natural
    }

    /// Shared CIContext for rendering efficiency.
    static let sharedContext = CIContext(options: nil)

    /// Analyzes the given image and recommends a filter.
    ///
    /// - Parameters:
    ///   - image: The input `CIImage` to analyze.
    ///   - context: The `CIContext` used for rendering the analysis filter.
    /// - Returns: A `SceneRecommendation` detailing the suggested filter.
    static func recommend(for image: CIImage, context: CIContext = sharedContext) -> SceneRecommendation {
        // Fallback to natural if extent is invalid or infinite
        guard !image.extent.isEmpty, !image.extent.isInfinite else {
            lastFilterType = .natural
            return SceneRecommendation(sceneDescription: "Balanced scene", filterName: "Natural", reason: "Scene looks great as-is, no filter needed")
        }
        
        let extent = image.extent
        
        // 1. Calculate average brightness using CIAreaAverage filter
        let areaAverageFilter = CIFilter.areaAverage()
        areaAverageFilter.inputImage = image
        areaAverageFilter.extent = extent
        
        guard let outputImage = areaAverageFilter.outputImage else {
            lastFilterType = .natural
            return SceneRecommendation(sceneDescription: "Balanced scene", filterName: "Natural", reason: "Scene looks great as-is, no filter needed")
        }
        
        // Render to a 1x1 bitmap to read average color
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage,
                       toBitmap: &bitmap,
                       rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8,
                       colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        
        // Read pixel data
        let r = CGFloat(bitmap[0]) / 255.0
        let g = CGFloat(bitmap[1]) / 255.0
        let b = CGFloat(bitmap[2]) / 255.0
        
        // Brightness
        let brightness = (r + g + b) / 3.0
        
        // 2 & 3. Scenarios and logic
        if brightness > 0.45 && b > r {
            lastFilterType = .cool
            return SceneRecommendation(
                sceneDescription: "Bright scene with cool tones",
                filterName: "Cool F160C",
                reason: "Cool filter enhances the blue tones in the scene"
            )
        } else if brightness > 0.45 && r > b {
            lastFilterType = .warm
            return SceneRecommendation(
                sceneDescription: "Bright scene with warm tones",
                filterName: "Warm Classic",
                reason: "Warm filter brings out the golden hues"
            )
        } else if brightness <= 0.25 {
            lastFilterType = .night
            return SceneRecommendation(
                sceneDescription: "Low light scene",
                filterName: "Night Boost",
                reason: "Enhanced contrast and exposure for dark scenes"
            )
        } else {
            lastFilterType = .natural
            return SceneRecommendation(
                sceneDescription: "Balanced scene",
                filterName: "Natural",
                reason: "Scene looks great as-is, no filter needed"
            )
        }
    }
    
    /// Applies the last recommended filter to a given `UIImage`.
    ///
    /// - Parameter image: The `UIImage` to process.
    /// - Returns: A new `UIImage` with the filter applied, or the original image if no filter or natural was recommended.
    static func applyLastFilter(to image: UIImage) -> UIImage {
        guard lastFilterType != .natural,
              let cgImage = image.cgImage else {
            return image
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        let outputImage: CIImage?
        
        // 4. Apply specific CIFilter configurations based on the last recommendation
        switch lastFilterType {
        case .cool:
            let filter = CIFilter.temperatureAndTint()
            filter.inputImage = ciImage
            filter.neutral = CIVector(x: 5500, y: 0)
            filter.targetNeutral = CIVector(x: 7500, y: 0)
            outputImage = filter.outputImage
        case .warm:
            let filter = CIFilter.temperatureAndTint()
            filter.inputImage = ciImage
            filter.neutral = CIVector(x: 5500, y: 0)
            filter.targetNeutral = CIVector(x: 4000, y: 0)
            outputImage = filter.outputImage
        case .night:
            let filter = CIFilter.colorControls()
            filter.inputImage = ciImage
            filter.contrast = 1.15
            filter.brightness = 0.05
            outputImage = filter.outputImage
        case .natural:
            outputImage = nil
        }
        
        // Render and return the final image
        guard let finalCIImage = outputImage,
              let finalCGImage = sharedContext.createCGImage(finalCIImage, from: finalCIImage.extent) else {
            return image
        }
        
        return UIImage(cgImage: finalCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

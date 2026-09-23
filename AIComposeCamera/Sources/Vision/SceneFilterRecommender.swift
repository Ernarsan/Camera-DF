import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Represents a scene filter recommendation based on image analysis.
struct SceneRecommendation {
    let sceneDescription: String
    let filterName: String
    let reason: String
}

/// Analyzes scene brightness, color temperature, and contrast to recommend a CIFilter.
class SceneFilterRecommender {
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
        case neon
        case natural
        case vivid
    }

    /// Shared CIContext for rendering efficiency.
    static let sharedContext = CIContext(options: nil)

    static func recommend(for image: CIImage, context: CIContext = sharedContext) -> SceneRecommendation {
        guard !image.extent.isEmpty, !image.extent.isInfinite else {
            lastFilterType = .natural
            return SceneRecommendation(sceneDescription: "Balanced", filterName: "Natural", reason: "Standard lighting detected")
        }
        
        let extent = image.extent
        let areaAverageFilter = CIFilter.areaAverage()
        areaAverageFilter.inputImage = image
        areaAverageFilter.extent = extent
        
        guard let outputImage = areaAverageFilter.outputImage else {
            lastFilterType = .natural
            return SceneRecommendation(sceneDescription: "Balanced", filterName: "Natural", reason: "Standard lighting detected")
        }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage,
                       toBitmap: &bitmap,
                       rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8,
                       colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        
        let r = CGFloat(bitmap[0]) / 255.0
        let g = CGFloat(bitmap[1]) / 255.0
        let b = CGFloat(bitmap[2]) / 255.0
        let brightness = (r + g + b) / 3.0
        
        // Smart AI Scenarios
        if brightness < 0.20 {
            // Low Light
            if r > g && r > b + 0.1 {
                lastFilterType = .neon
                return SceneRecommendation(
                    sceneDescription: "Cyberpunk / Neon Night",
                    filterName: "Neon Shift",
                    reason: "Boosts red/magenta luminance for striking night portraits"
                )
            } else {
                lastFilterType = .night
                return SceneRecommendation(
                    sceneDescription: "Low Light Scene",
                    filterName: "Night Boost",
                    reason: "Enhances shadow details and mitigates noise"
                )
            }
        } else if brightness > 0.70 {
            // Very Bright
            if b > r + 0.1 {
                lastFilterType = .cool
                return SceneRecommendation(
                    sceneDescription: "Bright Sky / Snow",
                    filterName: "Cool Blue",
                    reason: "Cooler temperature preserves highlight details in skies"
                )
            } else if r > b + 0.1 && g > b {
                lastFilterType = .warm
                return SceneRecommendation(
                    sceneDescription: "Golden Hour",
                    filterName: "Warm Glow",
                    reason: "Accentuates golden light and enhances skin tones"
                )
            } else {
                lastFilterType = .natural
                return SceneRecommendation(
                    sceneDescription: "Harsh Lighting",
                    filterName: "Natural HDR",
                    reason: "Balances extreme highlights"
                )
            }
        } else {
            // Mid-tones
            if g > r && g > b {
                lastFilterType = .vivid
                return SceneRecommendation(
                    sceneDescription: "Lush Nature",
                    filterName: "Vivid Green",
                    reason: "Saturates foliage and earth tones"
                )
            } else {
                lastFilterType = .natural
                return SceneRecommendation(
                    sceneDescription: "Balanced Studio Light",
                    filterName: "Natural",
                    reason: "Perfectly exposed mid-tones"
                )
            }
        }
    }
    
    static func applyLastFilter(to image: UIImage) -> UIImage {
        guard lastFilterType != .natural,
              let cgImage = image.cgImage else {
            return image
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        let outputImage: CIImage?
        
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
            filter.brightness = 0.08
            outputImage = filter.outputImage
        case .neon:
            let filter = CIFilter.colorControls()
            filter.inputImage = ciImage
            filter.contrast = 1.30
            filter.saturation = 1.40
            outputImage = filter.outputImage
        case .vivid:
            let filter = CIFilter.colorControls()
            filter.inputImage = ciImage
            filter.contrast = 1.10
            filter.saturation = 1.25
            outputImage = filter.outputImage
        case .natural:
            outputImage = nil
        }
        
        guard let finalCIImage = outputImage,
              let finalCGImage = sharedContext.createCGImage(finalCIImage, from: finalCIImage.extent) else {
            return image
        }
        
        return UIImage(cgImage: finalCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

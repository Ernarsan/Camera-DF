import UIKit
import CoreImage

/// Result of evaluating and enhancing an image for low-light conditions.
public struct NightEnhanceResult {
    /// Indicates whether the scene was determined to be dark (average brightness < threshold).
    public let isLowLight: Bool
    
    /// The enhanced image result after processing, or `nil` if not low light or if processing failed.
    public let enhancedImage: UIImage?
    
    public init(isLowLight: Bool, enhancedImage: UIImage?) {
        self.isLowLight = isLowLight
        self.enhancedImage = enhancedImage
    }
}

/// Enhances photos captured in low-light conditions using CoreImage filter chains.
public enum NightEnhancer {
    
    /// Low-light threshold for average scene brightness (0.0 ... 1.0).
    /// Brightness below this value is considered low light.
    public static let lowLightThreshold: Float = 0.25
    
    /// Shared CIContext reused across evaluations and renders for maximum efficiency.
    private static let sharedContext = CIContext(options: [
        .useSoftwareRenderer: false
    ])
    
    /// Analyzes the image brightness and applies low-light enhancement filters if needed.
    ///
    /// - Parameter image: The source `UIImage` to analyze and potentially enhance.
    /// - Returns: A `NightEnhanceResult` containing the detection flag and the enhanced image (if applicable).
    public static func enhanceIfNeeded(_ image: UIImage) -> NightEnhanceResult {
        // 1. Convert UIImage to CIImage
        guard let inputCIImage = image.ciImage ?? (image.cgImage.map { CIImage(cgImage: $0) }) else {
            return NightEnhanceResult(isLowLight: false, enhancedImage: nil)
        }
        
        // 2. Calculate average brightness using CIAreaAverage
        guard let brightness = calculateBrightness(for: inputCIImage) else {
            return NightEnhanceResult(isLowLight: false, enhancedImage: nil)
        }
        
        // 3. Threshold check: brightness < 0.25
        guard brightness < lowLightThreshold else {
            return NightEnhanceResult(isLowLight: false, enhancedImage: nil)
        }
        
        // 4. Apply filter chain: CIExposureAdjust -> CIColorControls -> CINoiseReduction
        let processedCIImage = applyEnhancementFilters(to: inputCIImage)
        
        // 5. Render final CIImage back to UIImage using CIContext
        guard let cgImage = sharedContext.createCGImage(processedCIImage, from: inputCIImage.extent) else {
            return NightEnhanceResult(isLowLight: true, enhancedImage: nil)
        }
        
        let enhancedImage = UIImage(
            cgImage: cgImage,
            scale: image.scale,
            orientation: image.imageOrientation
        )
        
        return NightEnhanceResult(isLowLight: true, enhancedImage: enhancedImage)
    }
    
    /// Calculates the average brightness of a `CIImage` using `CIAreaAverage`.
    ///
    /// - Parameter ciImage: The image to evaluate.
    /// - Returns: Normalized brightness between 0.0 (pitch black) and 1.0 (pure white), or `nil` if analysis fails.
    public static func calculateBrightness(for ciImage: CIImage) -> Float? {
        guard !ciImage.extent.isEmpty, !ciImage.extent.isInfinite else {
            return nil
        }
        
        guard let filter = CIFilter(name: "CIAreaAverage") else {
            return nil
        }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: ciImage.extent), forKey: kCIInputExtentKey)
        
        guard let outputImage = filter.outputImage else {
            return nil
        }
        
        // CIAreaAverage produces a 1x1 pixel image at the extent origin.
        // Translate the pixel to origin (0, 0) for reliable buffer extraction.
        let translatedImage = outputImage.transformed(by: CGAffineTransform(
            translationX: -outputImage.extent.origin.x,
            y: -outputImage.extent.origin.y
        ))
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        let renderBounds = CGRect(x: 0, y: 0, width: 1, height: 1)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        sharedContext.render(
            translatedImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: renderBounds,
            format: .RGBA8,
            colorSpace: colorSpace
        )
        
        let red = Float(bitmap[0])
        let green = Float(bitmap[1])
        let blue = Float(bitmap[2])
        
        // Average brightness across RGB channels normalized to 0.0 ... 1.0
        return (red + green + blue) / (3.0 * 255.0)
    }
    
    /// Applies the low-light enhancement filter chain to a `CIImage`.
    ///
    /// Filters applied:
    /// 1. `CIExposureAdjust` (inputEV = 1.5)
    /// 2. `CIColorControls` (inputContrast = 1.1, inputSaturation = 1.15)
    /// 3. `CINoiseReduction` (inputNoiseLevel = 0.03, inputSharpness = 0.5)
    ///
    /// - Parameter ciImage: The input image to enhance.
    /// - Returns: The filtered `CIImage` cropped to the input extent.
    public static func applyEnhancementFilters(to ciImage: CIImage) -> CIImage {
        var currentImage = ciImage
        
        // 1. Exposure adjustment (+1.5 EV boost)
        if let exposureFilter = CIFilter(name: "CIExposureAdjust") {
            exposureFilter.setValue(currentImage, forKey: kCIInputImageKey)
            exposureFilter.setValue(1.5, forKey: kCIInputEVKey)
            if let output = exposureFilter.outputImage {
                currentImage = output
            }
        }
        
        // 2. Color controls (Contrast: 1.1, Saturation: 1.15)
        if let colorFilter = CIFilter(name: "CIColorControls") {
            colorFilter.setValue(currentImage, forKey: kCIInputImageKey)
            colorFilter.setValue(1.1, forKey: kCIInputContrastKey)
            colorFilter.setValue(1.15, forKey: kCIInputSaturationKey)
            if let output = colorFilter.outputImage {
                currentImage = output
            }
        }
        
        // 3. Noise reduction (Noise level: 0.03, Sharpness: 0.5)
        if let noiseFilter = CIFilter(name: "CINoiseReduction") {
            noiseFilter.setValue(currentImage, forKey: kCIInputImageKey)
            noiseFilter.setValue(0.03, forKey: "inputNoiseLevel")
            noiseFilter.setValue(0.5, forKey: "inputSharpness")
            if let output = noiseFilter.outputImage {
                currentImage = output
            }
        }
        
        return currentImage.cropped(to: ciImage.extent)
    }
}

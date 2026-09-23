import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Provides computational photography enhancements (Super Resolution simulation)
/// for high digital zoom factors (5x - 10x) similar to modern flagship phones.
public class AIZoomEnhancer {
    
    // Shared context with high quality downsample and hardware acceleration
    private static let context = CIContext(options: [
        .useSoftwareRenderer: false,
        .highQualityDownsample: true
    ])
    
    /// Enhances the image if the zoom factor is high enough.
    /// Uses computational sharpening, noise reduction, and micro-contrast recovery.
    public static func enhance(image: UIImage, zoomFactor: CGFloat) -> UIImage {
        // Only activate AI enhancement for 5x zoom or greater
        guard zoomFactor >= 5.0, let cgImage = image.cgImage else {
            return image
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        var current = ciImage
        
        // 1. AI Noise Reduction (Removes digital crop artifacts)
        if let nr = CIFilter(name: "CINoiseReduction") {
            nr.setValue(current, forKey: kCIInputImageKey)
            // The higher the zoom, the more aggressively we reduce noise
            let noiseLevel = min(0.08, 0.02 + (Double(zoomFactor) * 0.005))
            nr.setValue(NSNumber(value: noiseLevel), forKey: "inputNoiseLevel")
            nr.setValue(NSNumber(value: 0.85), forKey: "inputSharpness")
            current = nr.outputImage ?? current
        }
        
        // 2. AI Edge Sharpening (Unsharp Mask restores edges lost during digital zoom)
        if let unsharp = CIFilter(name: "CIUnsharpMask") {
            unsharp.setValue(current, forKey: kCIInputImageKey)
            // Higher radius for high zoom to recreate edge structures
            let radius = min(4.5, 1.5 + (Double(zoomFactor) * 0.25))
            unsharp.setValue(NSNumber(value: radius), forKey: kCIInputRadiusKey)
            unsharp.setValue(NSNumber(value: 1.8), forKey: kCIInputIntensityKey)
            current = unsharp.outputImage ?? current
        }
        
        // 3. Micro-Contrast & Detail Recovery
        if let colorControls = CIFilter(name: "CIColorControls") {
            colorControls.setValue(current, forKey: kCIInputImageKey)
            colorControls.setValue(NSNumber(value: 1.08), forKey: kCIInputContrastKey) // subtle contrast boost
            colorControls.setValue(NSNumber(value: 1.15), forKey: kCIInputSaturationKey) // recover washed-out digital colors
            current = colorControls.outputImage ?? current
        }
        
        // Crop back to original extent to prevent edge bleeding
        current = current.cropped(to: ciImage.extent)
        
        guard let finalCG = context.createCGImage(current, from: current.extent) else {
            return image
        }
        
        return UIImage(cgImage: finalCG, scale: image.scale, orientation: image.imageOrientation)
    }
}

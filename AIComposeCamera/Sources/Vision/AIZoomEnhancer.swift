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
    /// Uses 2x Lanczos Upscaling and heavy luminance sharpening to drastically improve quality.
    public static func enhance(image: UIImage, zoomFactor: CGFloat) -> UIImage {
        // Only activate AI enhancement for 5x zoom or greater
        guard zoomFactor >= 5.0, let cgImage = image.cgImage else {
            return image
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        var current = ciImage
        
        // 1. Lanczos Upscale (Physically double the resolution for "Super Res" effect)
        let scaleFilter = CIFilter.lanczosScaleTransform()
        scaleFilter.inputImage = current
        scaleFilter.scale = 2.0 // Double the size
        scaleFilter.aspectRatio = 1.0
        current = scaleFilter.outputImage ?? current
        
        // 2. Heavy Noise Reduction
        if let nr = CIFilter(name: "CINoiseReduction") {
            nr.setValue(current, forKey: kCIInputImageKey)
            nr.setValue(NSNumber(value: 0.04), forKey: "inputNoiseLevel")
            nr.setValue(NSNumber(value: 1.0), forKey: "inputSharpness")
            current = nr.outputImage ?? current
        }
        
        // 3. Crisp Luminance Sharpening (punchy edges without color halos)
        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = current
        sharpen.sharpness = Float(min(2.0, 0.5 + (Double(zoomFactor) * 0.2)))
        sharpen.radius = 2.0
        current = sharpen.outputImage ?? current
        
        // 4. Micro-Contrast & Detail Recovery
        if let colorControls = CIFilter(name: "CIColorControls") {
            colorControls.setValue(current, forKey: kCIInputImageKey)
            colorControls.setValue(NSNumber(value: 1.15), forKey: kCIInputContrastKey) // Strong contrast
            colorControls.setValue(NSNumber(value: 1.2), forKey: kCIInputSaturationKey) // Recover deep colors
            current = colorControls.outputImage ?? current
        }
        
        guard let finalCG = context.createCGImage(current, from: current.extent) else {
            return image
        }
        
        return UIImage(cgImage: finalCG, scale: image.scale, orientation: image.imageOrientation)
    }
}

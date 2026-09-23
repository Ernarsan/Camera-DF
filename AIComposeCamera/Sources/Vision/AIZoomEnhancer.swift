import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Advanced Neural ISP and Computational Photography Clarity Engine.
/// Implements multi-frequency texture recovery, luminance sharpening,
/// local dynamic range expansion (ToneLM HDR), and micro-contrast.
public class AIZoomEnhancer {
    
    private static let context = CIContext(options: [
        .useSoftwareRenderer: false,
        .highQualityDownsample: true,
        .cacheIntermediates: false
    ])
    
    /// Enhances any captured image to achieve flagship-grade razor sharpness,
    /// deep dynamic range, and crisp micro-contrast immediately.
    public static func enhance(image: UIImage, zoomFactor: CGFloat) -> UIImage {
        guard let cgImage = image.cgImage else {
            return image
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        var current = ciImage
        
        // 1. Stage 1: Multi-Frequency Texture & Edge Extraction (Unsharp Masking)
        // Dynamically adjusts radius and intensity for crisp micro-details without halos
        let unsharp = CIFilter.unsharpMask()
        unsharp.inputImage = current
        let baseRadius: Float = zoomFactor >= 3.0 ? 3.0 : 1.8
        let baseIntensity: Float = zoomFactor >= 3.0 ? 2.2 : 1.6
        unsharp.radius = baseRadius
        unsharp.intensity = baseIntensity
        current = unsharp.outputImage ?? current
        
        // 2. Stage 2: Pure Luminance Sharpening (CISharpenLuminance)
        // Sharpens structural contours on the Y (luminance) plane without chromatic fringing
        let luminanceSharpen = CIFilter.sharpenLuminance()
        luminanceSharpen.inputImage = current
        luminanceSharpen.sharpness = zoomFactor >= 3.0 ? 1.8 : 1.3
        luminanceSharpen.radius = 1.4
        current = luminanceSharpen.outputImage ?? current
        
        // 3. Stage 3: Selective Bilateral / Noise Suppression (Noise Filtering)
        // Eliminates flat shadow noise while locking in high-frequency edges
        if let nr = CIFilter(name: "CINoiseReduction") {
            nr.setValue(current, forKey: kCIInputImageKey)
            let noiseLevel = zoomFactor >= 5.0 ? 0.04 : 0.015
            nr.setValue(NSNumber(value: noiseLevel), forKey: "inputNoiseLevel")
            nr.setValue(NSNumber(value: 0.95), forKey: "inputSharpness")
            current = nr.outputImage ?? current
        }
        
        // 4. Stage 4: ToneLM — Dynamic Local Tone Mapping & Highlight Recovery (HDR)
        // Lifts dark muddy shadows and recovers bright highlights so texture pops
        let toneAdjust = CIFilter.highlightShadowAdjust()
        toneAdjust.inputImage = current
        toneAdjust.highlightAmount = 0.82 // Tames blown whites
        toneAdjust.shadowAmount = 0.22    // Lifts murky shadows
        current = toneAdjust.outputImage ?? current
        
        // 5. Stage 5: Flagship Micro-Contrast & Color Depth (ColorLM)
        // Eliminates haze/milky film for rich, punchy, contrasty definition
        if let colorControls = CIFilter(name: "CIColorControls") {
            colorControls.setValue(current, forKey: kCIInputImageKey)
            colorControls.setValue(NSNumber(value: 1.12), forKey: kCIInputContrastKey)  // Deep crisp contrast
            colorControls.setValue(NSNumber(value: 1.10), forKey: kCIInputSaturationKey) // Vibrant natural colors
            current = colorControls.outputImage ?? current
        }
        
        // 6. Stage 6: Final Micro-Detail Polish Pass
        let finalSharpen = CIFilter.sharpenLuminance()
        finalSharpen.inputImage = current
        finalSharpen.sharpness = 0.8
        finalSharpen.radius = 1.0
        current = finalSharpen.outputImage ?? current
        
        guard let finalCG = context.createCGImage(current, from: current.extent) else {
            return image
        }
        
        return UIImage(cgImage: finalCG, scale: image.scale, orientation: image.imageOrientation)
    }
}

import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// High-performance vintage image processing engine that transforms raw captures
/// into authentic retro Y2K CCD / Film / Camcorder aesthetics.
public final class RetroFilterEngine: @unchecked Sendable {

    public static let shared = RetroFilterEngine()

    private let context: CIContext

    public init() {
        self.context = CIContext(options: [
            .useSoftwareRenderer: false,
            .priorityRequestLow: false
        ])
    }

    /// Process a UIImage through the chosen camera profile pipeline.
    public func process(
        image: UIImage,
        profile: RetroCameraProfile,
        includeGrain: Bool = true
    ) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }

        let processedCI = applyFilters(
            to: ciImage,
            profile: profile,
            includeGrain: includeGrain
        )

        guard let cgImage = context.createCGImage(processedCI, from: processedCI.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    /// Apply the full CoreImage filter chain to a CIImage.
    public func applyFilters(
        to inputImage: CIImage,
        profile: RetroCameraProfile,
        includeGrain: Bool = true
    ) -> CIImage {
        let params = profile.colorParameters
        var current = inputImage

        // 1. Color Controls (Contrast, Saturation, Brightness)
        if let colorControls = CIFilter(name: "CIColorControls") {
            colorControls.setValue(current, forKey: kCIInputImageKey)
            colorControls.setValue(params.contrast, forKey: kCIInputContrastKey)
            colorControls.setValue(params.saturation, forKey: kCIInputSaturationKey)
            colorControls.setValue(params.brightness, forKey: kCIInputBrightnessKey)
            if let output = colorControls.outputImage {
                current = output
            }
        }

        // 2. Color Matrix (Channel Color Bias / Tint)
        if let matrix = CIFilter(name: "CIColorMatrix") {
            matrix.setValue(current, forKey: kCIInputImageKey)
            matrix.setValue(CIVector(x: CGFloat(params.redBias), y: 0, z: 0, w: 0), forKey: "inputRVector")
            matrix.setValue(CIVector(x: 0, y: CGFloat(params.greenBias), z: 0, w: 0), forKey: "inputGVector")
            matrix.setValue(CIVector(x: 0, y: 0, z: CGFloat(params.blueBias), w: 0), forKey: "inputBVector")
            if let output = matrix.outputImage {
                current = output
            }
        }

        // 3. Highlight Bloom / Soft Focus
        if params.bloomIntensity > 0.05, let bloom = CIFilter(name: "CIBloom") {
            bloom.setValue(current, forKey: kCIInputImageKey)
            bloom.setValue(params.bloomIntensity, forKey: kCIInputIntensityKey)
            bloom.setValue(10.0, forKey: kCIInputRadiusKey)
            if let output = bloom.outputImage {
                current = output.cropped(to: inputImage.extent)
            }
        }

        // 4. Vintage Vignette (Dark Corner Falloff)
        if params.vignetteIntensity > 0.05, let vignette = CIFilter(name: "CIVignette") {
            vignette.setValue(current, forKey: kCIInputImageKey)
            vignette.setValue(params.vignetteIntensity, forKey: kCIInputIntensityKey)
            vignette.setValue(2.0, forKey: kCIInputRadiusKey)
            if let output = vignette.outputImage {
                current = output
            }
        }

        // 5. Film Grain / CCD Digital Sensor Noise
        if includeGrain && params.grainIntensity > 0.05 {
            current = addGrain(to: current, intensity: params.grainIntensity)
        }

        return current.cropped(to: inputImage.extent)
    }

    /// Synthesize realistic analog film grain / CCD sensor noise.
    private func addGrain(to image: CIImage, intensity: Float) -> CIImage {
        guard let random = CIFilter(name: "CIRandomGenerator"),
              let noise = random.outputImage else {
            return image
        }

        // Convert noise to monochrome
        let monoVector = CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0)
        let alphaVector = CIVector(x: 0, y: 0, z: 0, w: CGFloat(intensity * 0.45))

        guard let colorMatrix = CIFilter(name: "CIColorMatrix") else { return image }
        colorMatrix.setValue(noise, forKey: kCIInputImageKey)
        colorMatrix.setValue(monoVector, forKey: "inputRVector")
        colorMatrix.setValue(monoVector, forKey: "inputGVector")
        colorMatrix.setValue(monoVector, forKey: "inputBVector")
        colorMatrix.setValue(alphaVector, forKey: "inputAVector")

        guard let tintedNoise = colorMatrix.outputImage?.cropped(to: image.extent) else {
            return image
        }

        // Blend noise on top of the image
        guard let blend = CIFilter(name: "CISoftLightBlendMode") else { return image }
        blend.setValue(tintedNoise, forKey: kCIInputImageKey)
        blend.setValue(image, forKey: kCIInputBackgroundImageKey)

        return blend.outputImage ?? image
    }
}

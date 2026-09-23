import CoreImage
import UIKit

/// Applies a 512x512 (64x64x64 dimension) Color Lookup Table (LUT) to an image.
public class LUTFilter: CIFilter {
    @objc dynamic public var inputImage: CIImage?
    @objc dynamic public var lutImage: UIImage?

    private var colorCubeFilter: CIFilter?

    public override var outputImage: CIImage? {
        guard let inputImage = inputImage, let lutImage = lutImage else {
            return nil
        }
        
        if colorCubeFilter == nil {
            colorCubeFilter = CIFilter(name: "CIColorCube")
            
            // Generate cube data from the 512x512 UIImage
            if let cubeData = LUTFilter.createColorCubeData(from: lutImage) {
                colorCubeFilter?.setValue(64, forKey: "inputCubeDimension")
                colorCubeFilter?.setValue(cubeData, forKey: "inputCubeData")
            }
        }
        
        colorCubeFilter?.setValue(inputImage, forKey: kCIInputImageKey)
        return colorCubeFilter?.outputImage
    }
    
    public override func setDefaults() {
        super.setDefaults()
        colorCubeFilter = nil
    }

    /// Converts a 512x512 (8x8 tiles of 64x64) LUT image into a raw float byte array for CIColorCube.
    private static func createColorCubeData(from image: UIImage) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        let dimension = 64
        
        guard width == 512 && height == 512 else {
            print("[LUTFilter] Error: LUT image must be exactly 512x512.")
            return nil
        }

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        guard let context = CGContext(data: &pixels,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: bytesPerRow,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: bitmapInfo) else {
            return nil
        }
        
        // Flip the context vertically to match UIImage coordinate system
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1.0, y: -1.0)
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        let cubeDataSize = dimension * dimension * dimension * 4 * MemoryLayout<Float>.size
        var cubeData = [Float](repeating: 0, count: cubeDataSize / MemoryLayout<Float>.size)
        
        var offset = 0
        let tileRowCount = 8
        let tileColumnCount = 8
        
        for z in 0..<dimension {
            let row = z / tileColumnCount
            let col = z % tileColumnCount
            
            for y in 0..<dimension {
                for x in 0..<dimension {
                    let pixelX = col * dimension + x
                    let pixelY = row * dimension + y
                    
                    let pixelOffset = (pixelY * width + pixelX) * bytesPerPixel
                    
                    let r = Float(pixels[pixelOffset]) / 255.0
                    let g = Float(pixels[pixelOffset + 1]) / 255.0
                    let b = Float(pixels[pixelOffset + 2]) / 255.0
                    let a = Float(pixels[pixelOffset + 3]) / 255.0
                    
                    cubeData[offset] = r
                    cubeData[offset + 1] = g
                    cubeData[offset + 2] = b
                    cubeData[offset + 3] = a
                    offset += 4
                }
            }
        }
        
        return Data(bytes: cubeData, count: cubeData.count * MemoryLayout<Float>.size)
    }
}

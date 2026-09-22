import SwiftUI
import CoreImage

/// Iconic vintage camera models inspired by Kapi Cam Y2K CCD aesthetic.
public enum RetroCameraProfile: String, CaseIterable, Identifiable, Sendable {
    case ccd = "CCD"
    case g7x = "G7X"
    case nokia = "NOKIA"
    case lomo = "LOMO"
    case xt30 = "XT30"
    case dv = "DV Cam"
    case pola = "POLA"

    public var id: String { rawValue }

    /// Human-friendly display title
    public var displayName: String {
        switch self {
        case .ccd: return "CCD Y2K"
        case .g7x: return "G7X Flash"
        case .nokia: return "NOKIA 2000"
        case .lomo: return "LOMO LC-A"
        case .xt30: return "XT30 Film"
        case .dv: return "DV Camcorder"
        case .pola: return "POLA Instant"
        }
    }

    /// Subtitle describing the aesthetic
    public var subtitle: String {
        switch self {
        case .ccd: return "Sony/Fuji 2000s Digicam"
        case .g7x: return "Canon Flattering Flash"
        case .nokia: return "Lo-Fi Early Phone Cam"
        case .lomo: return "Vignette & High Saturation"
        case .xt30: return "Classic Chrome Simulation"
        case .dv: return "90s Tape & Running Timecode"
        case .pola: return "Pastel Instant Film"
        }
    }

    /// SF Symbol for the camera badge
    public var iconSymbol: String {
        switch self {
        case .ccd: return "camera.aperture"
        case .g7x: return "bolt.badge.automatic.fill"
        case .nokia: return "antenna.radiowaves.left.and.right"
        case .lomo: return "circle.circle.fill"
        case .xt30: return "film.stack"
        case .dv: return "video.badge.waveform"
        case .pola: return "photo.on.rectangle"
        }
    }

    /// Accent badge color
    public var accentColor: Color {
        switch self {
        case .ccd: return Color(red: 1.0, green: 0.55, blue: 0.0) // Iconic Orange
        case .g7x: return Color(red: 0.95, green: 0.35, blue: 0.55) // Pinkish Flash
        case .nokia: return Color(red: 0.2, green: 0.8, blue: 0.6) // Nokia Green
        case .lomo: return Color(red: 1.0, green: 0.2, blue: 0.2) // Red Lomo
        case .xt30: return Color(red: 0.85, green: 0.75, blue: 0.5) // Vintage Tan
        case .dv: return Color(red: 0.2, green: 0.9, blue: 0.2) // Camcorder REC Green
        case .pola: return Color(red: 0.4, green: 0.7, blue: 1.0) // Polaroid Cyan
        }
    }

    /// Color matrix parameters [R, G, B, Contrast, Saturation, Brightness]
    public var colorParameters: RetroColorParams {
        switch self {
        case .ccd:
            return RetroColorParams(
                redBias: 1.08,
                greenBias: 0.98,
                blueBias: 0.92,
                contrast: 1.15,
                saturation: 1.12,
                brightness: 0.02,
                vignetteIntensity: 0.35,
                bloomIntensity: 0.15,
                grainIntensity: 0.22
            )
        case .g7x:
            return RetroColorParams(
                redBias: 1.05,
                greenBias: 1.02,
                blueBias: 1.04,
                contrast: 1.08,
                saturation: 1.18,
                brightness: 0.06,
                vignetteIntensity: 0.15,
                bloomIntensity: 0.38,
                grainIntensity: 0.10
            )
        case .nokia:
            return RetroColorParams(
                redBias: 0.94,
                greenBias: 1.06,
                blueBias: 0.98,
                contrast: 1.25,
                saturation: 0.90,
                brightness: -0.02,
                vignetteIntensity: 0.25,
                bloomIntensity: 0.05,
                grainIntensity: 0.35
            )
        case .lomo:
            return RetroColorParams(
                redBias: 1.15,
                greenBias: 0.95,
                blueBias: 1.10,
                contrast: 1.35,
                saturation: 1.40,
                brightness: 0.0,
                vignetteIntensity: 0.75,
                bloomIntensity: 0.10,
                grainIntensity: 0.25
            )
        case .xt30:
            return RetroColorParams(
                redBias: 1.02,
                greenBias: 0.96,
                blueBias: 0.94,
                contrast: 1.12,
                saturation: 0.95,
                brightness: 0.01,
                vignetteIntensity: 0.30,
                bloomIntensity: 0.12,
                grainIntensity: 0.28
            )
        case .dv:
            return RetroColorParams(
                redBias: 0.96,
                greenBias: 1.04,
                blueBias: 1.02,
                contrast: 1.10,
                saturation: 1.05,
                brightness: 0.03,
                vignetteIntensity: 0.20,
                bloomIntensity: 0.20,
                grainIntensity: 0.30
            )
        case .pola:
            return RetroColorParams(
                redBias: 1.06,
                greenBias: 1.02,
                blueBias: 0.90,
                contrast: 0.98,
                saturation: 0.92,
                brightness: 0.05,
                vignetteIntensity: 0.40,
                bloomIntensity: 0.25,
                grainIntensity: 0.18
            )
        }
    }

    /// Color of the stamped date in bottom-right corner
    public var dateStampColor: UIColor {
        switch self {
        case .ccd, .g7x, .xt30:
            return UIColor(red: 1.0, green: 0.45, blue: 0.0, alpha: 0.95) // Neon Amber/Orange
        case .nokia, .dv:
            return UIColor(red: 0.25, green: 0.95, blue: 0.35, alpha: 0.95) // Digicam Green
        case .lomo, .pola:
            return UIColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 0.95) // Warm Yellow
        }
    }
}

public struct RetroColorParams: Sendable {
    public let redBias: Float
    public let greenBias: Float
    public let blueBias: Float
    public let contrast: Float
    public let saturation: Float
    public let brightness: Float
    public let vignetteIntensity: Float
    public let bloomIntensity: Float
    public let grainIntensity: Float
}

public enum AspectRatioMode: String, CaseIterable, Identifiable, Sendable {
    case ratio4_3 = "4:3"
    case ratio1_1 = "1:1"
    case ratio16_9 = "16:9"

    public var id: String { rawValue }

    public var ratioMultiplier: CGFloat {
        switch self {
        case .ratio4_3: return 4.0 / 3.0
        case .ratio1_1: return 1.0
        case .ratio16_9: return 16.0 / 9.0
        }
    }
}

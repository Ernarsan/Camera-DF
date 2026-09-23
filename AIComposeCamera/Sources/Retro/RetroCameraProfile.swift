import SwiftUI
import CoreImage

/// High-end AI Camera processing profiles replacing the old retro filters.
public enum RetroCameraProfile: String, CaseIterable, Identifiable, Sendable {
    case leica = "Leica"
    case zeiss = "Zeiss"
    case aisp = "AISP"
    case vivo = "Vivo Blueprint"
    case fusion = "FusionLM"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .leica: return "Leica Authentic"
        case .zeiss: return "Zeiss Natural Color"
        case .aisp: return "AISP Ultra"
        case .vivo: return "Vivo Blueprint NICE"
        case .fusion: return "FusionLM HDR"
        }
    }

    public var subtitle: String {
        switch self {
        case .leica: return "Сохранение драматической светотени (Summilux)"
        case .zeiss: return "Апохроматическая оптика APO (T* покрытие)"
        case .aisp: return "Генеративное масштабирование текстур (GAN)"
        case .vivo: return "Реконструкция в несжатом RAW (14-bit)"
        case .fusion: return "Двойное аналоговое усиление (DAG HDR)"
        }
    }

    public var iconSymbol: String {
        switch self {
        case .leica: return "camera.aperture"
        case .zeiss: return "camera.macro"
        case .aisp: return "wand.and.stars"
        case .vivo: return "cpu"
        case .fusion: return "circle.hexagongrid"
        }
    }

    public var accentColor: Color {
        switch self {
        case .leica: return Color(red: 0.9, green: 0.1, blue: 0.1)
        case .zeiss: return Color(red: 0.0, green: 0.4, blue: 0.8)
        case .aisp: return Color(red: 0.8, green: 0.3, blue: 0.9)
        case .vivo: return Color(red: 0.2, green: 0.8, blue: 0.6)
        case .fusion: return Color(red: 1.0, green: 0.6, blue: 0.0)
        }
    }

    public var lutFile: (name: String, ext: String)? {
        return nil // Using pure params instead of old LUTs
    }

    public var colorParameters: RetroColorParams {
        switch self {
        case .leica:
            return RetroColorParams(redBias: 1.05, greenBias: 0.95, blueBias: 0.9, contrast: 1.25, saturation: 0.95, brightness: -0.05, vignetteIntensity: 0.4, bloomIntensity: 0.1, grainIntensity: 0.0)
        case .zeiss:
            return RetroColorParams(redBias: 1.0, greenBias: 1.0, blueBias: 1.05, contrast: 1.1, saturation: 1.05, brightness: 0.0, vignetteIntensity: 0.1, bloomIntensity: 0.0, grainIntensity: 0.0)
        case .aisp:
            return RetroColorParams(redBias: 1.02, greenBias: 1.02, blueBias: 0.98, contrast: 1.15, saturation: 1.1, brightness: 0.02, vignetteIntensity: 0.0, bloomIntensity: 0.2, grainIntensity: 0.0)
        case .vivo:
            return RetroColorParams(redBias: 1.0, greenBias: 1.0, blueBias: 1.0, contrast: 1.05, saturation: 1.15, brightness: 0.05, vignetteIntensity: 0.1, bloomIntensity: 0.05, grainIntensity: 0.0)
        case .fusion:
            return RetroColorParams(redBias: 0.98, greenBias: 1.05, blueBias: 1.0, contrast: 1.2, saturation: 1.0, brightness: 0.08, vignetteIntensity: 0.2, bloomIntensity: 0.3, grainIntensity: 0.0)
        }
    }

    public var dateStampColor: UIColor {
        switch self {
        case .leica: return UIColor.systemRed
        case .zeiss: return UIColor.systemBlue
        case .aisp: return UIColor.systemPurple
        case .vivo: return UIColor.systemTeal
        case .fusion: return UIColor.systemOrange
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

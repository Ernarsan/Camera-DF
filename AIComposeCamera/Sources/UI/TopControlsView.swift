import SwiftUI

/// Top control bar with Flash / Aspect Ratio / Date Stamp / Grain / Timer / Grid controls.
struct TopControlsView: View {

    @Binding var flashMode: FlashMode
    @Binding var isHDR: Bool
    @Binding var timerDuration: TimerDuration
    @Binding var showGrid: Bool
    @Binding var aspectRatio: AspectRatioMode
    @Binding var isDateStampEnabled: Bool
    @Binding var isGrainEnabled: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Flash Toggle
            Button {
                flashMode = flashMode.next
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .frame(width: 38, height: 38)

                    Image(systemName: flashMode.iconName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(flashMode.iconColor)
                }
            }

            // Aspect Ratio Toggle (4:3, 1:1, 16:9)
            Button {
                switch aspectRatio {
                case .ratio4_3: aspectRatio = .ratio1_1
                case .ratio1_1: aspectRatio = .ratio16_9
                case .ratio16_9: aspectRatio = .ratio4_3
                }
            } label: {
                Text(aspectRatio.rawValue)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
                    )
            }

            // Date Stamp Toggle (Y2K signature)
            Button {
                isDateStampEnabled.toggle()
            } label: {
                Text("DATE")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(isDateStampEnabled ? Color(red: 1.0, green: 0.55, blue: 0.0) : .white.opacity(0.4))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(isDateStampEnabled ? Color(red: 1.0, green: 0.55, blue: 0.0).opacity(0.2) : Color.white.opacity(0.08))
                    )
            }

            Spacer()

            // Grain Toggle
            Button {
                isGrainEnabled.toggle()
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .frame(width: 38, height: 38)

                    Image(systemName: "camera.filters")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isGrainEnabled ? .orange : .white.opacity(0.5))
                }
            }

            // Timer
            Button {
                timerDuration = timerDuration.next
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .frame(width: 38, height: 38)

                    Image(systemName: "timer")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(timerDuration == .off ? .white : .yellow)

                    if timerDuration != .off {
                        Text("\(timerDuration.seconds)")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.yellow)
                            .offset(x: 8, y: -8)
                    }
                }
            }

            // Grid
            Button {
                showGrid.toggle()
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .frame(width: 38, height: 38)

                    Image(systemName: "grid")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(showGrid ? .cyan : .white.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 14)
    }
}

// MARK: - Supporting Types

enum FlashMode: String, CaseIterable {
    case off, on, auto

    var iconName: String {
        switch self {
        case .off: return "bolt.slash.fill"
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.automatic.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .off: return .white
        case .on: return .yellow
        case .auto: return .cyan
        }
    }

    var next: FlashMode {
        switch self {
        case .off: return .on
        case .on: return .auto
        case .auto: return .off
        }
    }

    var avFlashMode: Int {
        switch self {
        case .off: return 0  // AVCaptureDevice.FlashMode.off.rawValue
        case .on: return 1   // AVCaptureDevice.FlashMode.on.rawValue
        case .auto: return 2 // AVCaptureDevice.FlashMode.auto.rawValue
        }
    }
}

enum TimerDuration: Int, CaseIterable {
    case off = 0
    case three = 3
    case five = 5
    case ten = 10

    var seconds: Int { rawValue }

    var next: TimerDuration {
        switch self {
        case .off: return .three
        case .three: return .five
        case .five: return .ten
        case .ten: return .off
        }
    }
}

import SwiftUI

/// Top control bar with Flash / HDR / Timer / Grid / Settings controls.
struct TopControlsView: View {

    @Binding var flashMode: FlashMode
    @Binding var isHDR: Bool
    @Binding var timerDuration: TimerDuration
    @Binding var showGrid: Bool

    var body: some View {
        HStack(spacing: 14) {
            // Flash Toggle
            Button {
                flashMode = flashMode.next
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .frame(width: 40, height: 40)

                    Image(systemName: flashMode.iconName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(flashMode.iconColor)
                }
            }

            // HDR Toggle
            Button {
                isHDR.toggle()
            } label: {
                Text("HDR")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(isHDR ? .black : .white.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(isHDR ? Color.yellow : Color.white.opacity(0.15))
                    )
            }

            Spacer()

            // Timer
            Button {
                timerDuration = timerDuration.next
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .frame(width: 40, height: 40)

                    Image(systemName: "timer")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(timerDuration == .off ? .white : .yellow)

                    if timerDuration != .off {
                        Text("\(timerDuration.seconds)")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.yellow)
                            .offset(x: 10, y: -10)
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
                        .frame(width: 40, height: 40)

                    Image(systemName: "grid")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(showGrid ? .cyan : .white)
                }
            }
        }
        .padding(.horizontal, 16)
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

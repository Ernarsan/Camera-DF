import SwiftUI

/// Camera mode: Photo, Video, or 360° Panorama.
enum CameraMode: String, CaseIterable, Identifiable {
    case photo = "PHOTO"
    case video = "VIDEO"
    case panorama = "360°"

    var id: String { rawValue }
}

/// Horizontal mode picker at the bottom of the camera screen.
struct ModePickerView: View {

    @Binding var selectedMode: CameraMode

    var body: some View {
        HStack(spacing: 28) {
            ForEach(CameraMode.allCases) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedMode = mode
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(mode.rawValue)
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1.2)
                            .foregroundColor(
                                selectedMode == mode
                                    ? modeAccentColor(mode)
                                    : .white.opacity(0.45)
                            )

                        // Active indicator dot
                        Circle()
                            .fill(
                                selectedMode == mode
                                    ? modeAccentColor(mode)
                                    : Color.clear
                            )
                            .frame(width: 5, height: 5)
                    }
                }
            }
        }
    }

    private func modeAccentColor(_ mode: CameraMode) -> Color {
        switch mode {
        case .photo: return .yellow
        case .video: return .red
        case .panorama: return .cyan
        }
    }
}

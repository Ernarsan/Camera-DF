import SwiftUI

/// Horizontal retro camera selector inspired by Kapi Cam's film / camera carousel.
struct CameraWheelPickerView: View {

    @Binding var selectedCamera: RetroCameraProfile

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(RetroCameraProfile.allCases) { profile in
                    let isSelected = (selectedCamera == profile)

                    Button {
                        let generator = UISelectionFeedbackGenerator()
                        generator.selectionChanged()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            selectedCamera = profile
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: profile.iconSymbol)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(isSelected ? profile.accentColor : .white.opacity(0.7))

                            Text(profile.rawValue)
                                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                .foregroundColor(isSelected ? .white : .white.opacity(0.65))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            ZStack {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color(white: 0.18))
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(profile.accentColor, lineWidth: 1.8)
                                } else {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.white.opacity(0.08))
                                }
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 18)
        }
    }
}

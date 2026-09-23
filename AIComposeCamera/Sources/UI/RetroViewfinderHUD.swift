import SwiftUI

/// Authentic retro camera LCD viewfinder HUD inspired by 2000s digicams and Kapi Cam.
struct RetroViewfinderHUD: View {

    let camera: RetroCameraProfile
    let aspectRatio: AspectRatioMode
    let isDateStampOn: Bool
    let isGrainOn: Bool
    let photoCount: Int
    let flashMode: FlashMode
    let isRecording: Bool
    let recordingDuration: TimeInterval
    let aiFilterRecommendation: String
    let currentZoomFactor: CGFloat
    let containerSize: CGSize
    
    @State private var blinkToggle: Bool = false

    var body: some View {
        ZStack {
            // MARK: - Aspect Ratio Framing Masks
            aspectRatioMask()

            // MARK: - LCD Information Overlay
            VStack {
                // Top LCD Status Bar
                HStack(spacing: 12) {
                    if isRecording {
                        // Blinking REC Indicator
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .opacity(blinkToggle ? 1.0 : 0.2)
                            
                            Text("REC")
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundColor(.red)
                            
                            Text(formatDuration(recordingDuration))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.leading, 4)
                        }
                    } else {
                        // Battery indicator
                        HStack(spacing: 3) {
                            Image(systemName: "battery.75")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.green)
                        }

                        // Remaining shots / frame count
                        Text(String(format: "[%03d]", max(0, 999 - photoCount)))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.yellow)

                        // Sensor / Format badge
                        Text(camera.rawValue)
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(camera.accentColor.opacity(0.85))
                            .foregroundColor(.black)
                            .cornerRadius(3)
                    }

                    Spacer()

                    if !isRecording {
                        // AI Filter Recommendation
                        if !aiFilterRecommendation.isEmpty && aiFilterRecommendation != "Natural" {
                            Text("AI: \(aiFilterRecommendation.uppercased())")
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.yellow.opacity(0.8))
                                .foregroundColor(.black)
                                .cornerRadius(2)
                        }

                        // AI Super Resolution for Zoom
                        if currentZoomFactor >= 5.0 {
                            Text("AI SUPER RES")
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.8))
                                .foregroundColor(.black)
                                .cornerRadius(2)
                        }

                        // Grain indicator
                        if isGrainOn {
                            Text("GRAIN")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                        }

                        // Aspect ratio indicator
                        Text(aspectRatio.rawValue)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)

                        // Flash indicator
                        HStack(spacing: 2) {
                            Image(systemName: flashMode.iconName)
                                .font(.system(size: 11, weight: .semibold))
                            Text(flashMode.rawValue.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(flashMode.iconColor)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.55))

                Spacer()

                // Bottom LCD Status Line
                HStack {
                    // Left: Exposure / ISO Readout
                    Text(aiFilterRecommendation == "Night Boost" || aiFilterRecommendation == "Neon Shift" ? "ISO 800  EV -1.0" : "ISO 100  EV +0.0")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(aiFilterRecommendation == "Night Boost" ? .yellow : .white.opacity(0.85))
                        .padding(.leading, 16)
                        .padding(.bottom, 12)

                    Spacer()

                    // Right: Iconic Glowing Y2K Date Stamp Preview
                    if isDateStampOn {
                        Text(RetroDateStamper.formattedDate(style: .currentYear))
                            .font(.custom("Menlo-BoldItalic", size: 14))
                            .foregroundColor(Color(camera.dateStampColor))
                            .shadow(color: Color(camera.dateStampColor).opacity(1.0), radius: 6)
                            .padding(.trailing, 16)
                            .padding(.bottom, 12)
                    }
                }
                .background(
                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                blinkToggle.toggle()
            }
        }
    }

    // Formats TimeInterval to mm:ss
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Aspect Ratio Masking

    @ViewBuilder
    private func aspectRatioMask() -> some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            switch aspectRatio {
            case .ratio4_3:
                // 4:3 means height = width * (4/3) in portrait
                let targetHeight = w * (4.0 / 3.0)
                let barHeight = max(0, (h - targetHeight) / 2.0)
                VStack(spacing: 0) {
                    Color.black.frame(height: barHeight)
                    Spacer()
                    Color.black.frame(height: barHeight)
                }
            case .ratio1_1:
                let barHeight = max(0, (h - w) / 2.0)
                VStack(spacing: 0) {
                    Color.black.frame(height: barHeight)
                    Spacer()
                    Color.black.frame(height: barHeight)
                }
            case .ratio16_9:
                EmptyView()
            }
        }
        .allowsHitTesting(false)
    }
}

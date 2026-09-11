import SwiftUI

/// Video recording controls overlay shown in video mode.
struct VideoControlsView: View {

    let isRecording: Bool
    let recordingDuration: TimeInterval
    let currentZoom: CGFloat
    let flashEnabled: Bool
    let onToggleRecording: () -> Void
    let onFlipCamera: () -> Void
    let onToggleFlash: () -> Void
    let onZoomTap: (CGFloat) -> Void
    let onBack: () -> Void

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Recording red border
            if isRecording {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.red, lineWidth: 3)
                    .ignoresSafeArea()
            }

            VStack {
                // Top Bar
                topBar
                    .padding(.top, 60)
                    .padding(.horizontal, 16)

                Spacer()

                // Zoom chips (only when not recording)
                if !isRecording {
                    zoomChips
                        .padding(.bottom, 16)
                }

                // Bottom controls
                controlRow
                    .padding(.bottom, 8)

                // Mode label
                Text("VIDEO")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
                    .foregroundColor(.red)
                    .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            if !isRecording {
                // Back button
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(.ultraThinMaterial).environment(\.colorScheme, .dark))
                }
            }

            Spacer()

            // Timer (visible when recording)
            if isRecording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .opacity(pulseScale > 1.0 ? 0.4 : 1.0)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                                pulseScale = 1.2
                            }
                        }

                    Text(formatDuration(recordingDuration))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.black.opacity(0.6)))
            }

            Spacer()

            // Flash toggle
            Button(action: onToggleFlash) {
                Image(systemName: flashEnabled ? "bolt.fill" : "bolt.slash.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(flashEnabled ? .yellow : .white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.ultraThinMaterial).environment(\.colorScheme, .dark))
            }
        }
    }

    // MARK: - Zoom Chips

    private var zoomChips: some View {
        HStack(spacing: 8) {
            ForEach([0.5, 1.0, 2.0, 5.0], id: \.self) { factor in
                Button {
                    onZoomTap(factor)
                } label: {
                    Text("\(factor == 0.5 ? "0.5" : "\(Int(factor))")x")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(
                            abs(currentZoom - factor) < 0.1 ? .white : .white.opacity(0.6)
                        )
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(
                                abs(currentZoom - factor) < 0.1
                                    ? Color.red.opacity(0.8)
                                    : Color.white.opacity(0.12)
                            )
                        )
                }
            }
        }
    }

    // MARK: - Control Row

    private var controlRow: some View {
        HStack(spacing: 50) {
            // Empty spacer (or gallery thumbnail)
            Color.clear.frame(width: 44, height: 44)

            // Record button
            Button(action: onToggleRecording) {
                ZStack {
                    Circle()
                        .stroke(Color.red, lineWidth: 4)
                        .frame(width: 76, height: 76)

                    if isRecording {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.red)
                            .frame(width: 28, height: 28)
                    } else {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 62, height: 62)
                    }
                }
            }

            // Flip camera
            Button(action: onFlipCamera) {
                Image(systemName: "camera.rotate.fill")
                    .font(.system(size: 22))
                    .foregroundColor(isRecording ? .gray : .white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .disabled(isRecording)
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hrs = Int(seconds) / 3600
        let mins = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hrs > 0 {
            return String(format: "%02d:%02d:%02d", hrs, mins, secs)
        }
        return String(format: "%02d:%02d", mins, secs)
    }
}

import SwiftUI

/// 360° Panorama capture view with guide dots and progress tracking.
struct PanoramaView: View {

    @ObservedObject var manager: PanoramaManager
    let onCapture: () -> Void
    let onBack: () -> Void
    let onSaveAll: () -> Void

    var body: some View {
        ZStack {
            if manager.isComplete {
                completionView
            } else {
                captureView
            }
        }
    }

    // MARK: - Active Capture View

    private var captureView: some View {
        VStack {
            // Top: Progress bar + info
            VStack(spacing: 10) {
                // Close button + title
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.red.opacity(0.7)))
                    }

                    Spacer()

                    Text("360° PANORAMA")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(2)
                        .foregroundColor(.cyan)

                    Spacer()

                    // Spacer for balance
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 16)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 6)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.cyan, .green],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geo.size.width * progressFraction,
                                height: 6
                            )
                            .animation(.easeInOut(duration: 0.3), value: manager.capturedCount)
                    }
                }
                .frame(height: 6)
                .padding(.horizontal, 20)

                // Counter text
                Text("\(manager.capturedCount) / \(manager.totalPoints) captured")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.top, 60)

            Spacer()

            // Center: Guide dots visualization
            guideDots
                .frame(width: 280, height: 280)

            // Instruction text
            instructionText
                .padding(.top, 12)

            Spacer()

            // Bottom: Capture button
            Button(action: onCapture) {
                ZStack {
                    Circle()
                        .stroke(Color.cyan, lineWidth: 3)
                        .frame(width: 72, height: 72)

                    Circle()
                        .fill(manager.nearbyPointIndex != nil ? Color.cyan : Color.white.opacity(0.3))
                        .frame(width: 58, height: 58)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 22))
                        .foregroundColor(manager.nearbyPointIndex != nil ? .black : .white.opacity(0.5))
                }
            }
            .disabled(manager.nearbyPointIndex == nil)
            .scaleEffect(manager.nearbyPointIndex != nil ? 1.0 : 0.9)
            .animation(.easeInOut(duration: 0.2), value: manager.nearbyPointIndex != nil)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Guide Dots

    private var guideDots: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                .frame(width: 260, height: 260)

            // Current position crosshair
            crosshair

            // Target dots
            ForEach(manager.capturePoints) { point in
                let pos = dotPosition(for: point, in: 260)
                Circle()
                    .fill(dotColor(for: point))
                    .frame(width: dotSize(for: point), height: dotSize(for: point))
                    .shadow(
                        color: point.isCaptured ? .green.opacity(0.6) : .clear,
                        radius: 4
                    )
                    .overlay(
                        point.isCaptured
                            ? Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.black)
                            : nil
                    )
                    .offset(x: pos.x, y: pos.y)
                    .animation(.easeOut(duration: 0.15), value: manager.currentPitch)
            }
        }
    }

    private var crosshair: some View {
        ZStack {
            // Horizontal line
            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 30, height: 1)

            // Vertical line
            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 1, height: 30)

            // Center dot
            Circle()
                .fill(Color.white)
                .frame(width: 6, height: 6)
        }
    }

    // MARK: - Instruction Text

    private var instructionText: some View {
        Group {
            if manager.nearbyPointIndex != nil {
                HStack(spacing: 6) {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.cyan)
                    Text("Tap to capture this position")
                        .foregroundColor(.cyan)
                }
                .font(.system(size: 14, weight: .semibold))
            } else {
                Text("Move your phone slowly to find the next position")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Capsule().fill(.ultraThinMaterial).environment(\.colorScheme, .dark))
    }

    // MARK: - Completion View

    private var completionView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.green)

            Text("Panorama Complete!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Text("All \(manager.totalPoints) positions captured successfully")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            VStack(spacing: 12) {
                Button(action: onSaveAll) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save All Photos")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.green)
                    )
                }

                Button(action: onBack) {
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.15))
                        )
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Helpers

    private var progressFraction: CGFloat {
        guard manager.totalPoints > 0 else { return 0 }
        return CGFloat(manager.capturedCount) / CGFloat(manager.totalPoints)
    }

    private func dotPosition(for point: PanoramaPoint, in containerSize: CGFloat) -> CGPoint {
        // Map pitch/yaw to 2D display coordinates using linear scaling
        let radius = containerSize * 0.4 // This acts as our "fov" scale
        
        var relYaw = point.targetYaw - manager.currentYaw
        // Normalize yaw so the shortest path is drawn
        while relYaw > .pi { relYaw -= 2 * .pi }
        while relYaw < -.pi { relYaw += 2 * .pi }
        
        let relPitch = point.targetPitch - manager.currentPitch
        
        // Scale radians directly to pixels (1 radian = `radius` pixels)
        let x = CGFloat(relYaw) * radius
        // Pitch is inverted: looking up (positive pitch) means dots move DOWN the screen
        let y = CGFloat(-relPitch) * radius

        return CGPoint(x: x, y: y)
    }

    private func dotColor(for point: PanoramaPoint) -> Color {
        if point.isCaptured {
            return .green
        }
        if let nearIdx = manager.nearbyPointIndex, nearIdx == point.id {
            return .yellow
        }
        return .white.opacity(0.3)
    }

    private func dotSize(for point: PanoramaPoint) -> CGFloat {
        if point.isCaptured { return 20 }
        if let nearIdx = manager.nearbyPointIndex, nearIdx == point.id { return 18 }
        return 14
    }
}

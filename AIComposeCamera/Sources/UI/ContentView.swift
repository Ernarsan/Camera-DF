import SwiftUI

/// Main screen: full-screen camera preview with AI overlays and controls.
struct ContentView: View {

    @StateObject private var viewModel = CameraViewModel()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // MARK: - Camera Preview (full screen)
                Color.black.ignoresSafeArea()

                CameraPreviewView(session: viewModel.captureSession)
                    .ignoresSafeArea()

                // MARK: - Alignment Mode Border
                if viewModel.isAlignmentModeOn {
                    alignmentBorder(size: geometry.size)
                }

                // MARK: - Saliency Box
                if let box = viewModel.suggestedBox, !viewModel.isAlignmentModeOn {
                    SaliencyBoxView(box: box, containerSize: geometry.size)
                }

                // MARK: - Alignment Target Dot
                if viewModel.isAlignmentModeOn, let target = viewModel.targetCompositionPoint {
                    targetDot(target: target, size: geometry.size)
                }

                // MARK: - Current Subject Point (small indicator)
                if viewModel.isAlignmentModeOn, let subject = viewModel.currentSubjectPoint {
                    subjectIndicator(subject: subject, size: geometry.size)
                }

                // MARK: - Overlay Controls
                VStack {
                    // Top: Suggestion Bubbles
                    topBubbles()

                    Spacer()

                    // Bottom: Controls
                    bottomControls()
                }
                .padding(.top, 60)
                .padding(.bottom, 30)

                // MARK: - Captured Photo Overlay
                if viewModel.showCapturedPhoto, let image = viewModel.capturedImage {
                    capturedPhotoOverlay(image: image)
                }

                // MARK: - No Camera Access
                if !viewModel.isCameraAuthorized {
                    noCameraAccessView()
                }
            }
        }
        .statusBarHidden(true)
        .onAppear {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    // MARK: - Top Bubbles

    @ViewBuilder
    private func topBubbles() -> some View {
        VStack(spacing: 8) {
            // Analyzing bubble
            if viewModel.isAnalyzing && !viewModel.isAlignmentModeOn {
                SuggestionBubbleView.analyzing
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Filter recommendation
            if !viewModel.filterName.isEmpty && !viewModel.isAnalyzing && !viewModel.isAlignmentModeOn {
                SuggestionBubbleView.filterRecommendation(
                    name: viewModel.filterName,
                    reason: viewModel.filterReason
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Alignment instruction
            if viewModel.isAlignmentModeOn && !viewModel.alignmentInstruction.isEmpty {
                SuggestionBubbleView.alignment(instruction: viewModel.alignmentInstruction)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Low light indicator
            if viewModel.isLowLight && !viewModel.isAlignmentModeOn {
                HStack(spacing: 4) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 12))
                    Text("Low Light — Night Boost will be applied")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.yellow)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.black.opacity(0.5)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isAnalyzing)
        .animation(.easeInOut(duration: 0.3), value: viewModel.filterName)
        .animation(.easeInOut(duration: 0.3), value: viewModel.alignmentInstruction)
    }

    // MARK: - Bottom Controls

    @ViewBuilder
    private func bottomControls() -> some View {
        VStack(spacing: 20) {
            // Zoom button
            if let zoom = viewModel.suggestedZoom, zoom > 1, !viewModel.isAlignmentModeOn {
                Button {
                    viewModel.applyZoom()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.magnifyingglass")
                        Text("Zoom to \(Int(zoom))x")
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.blue.opacity(0.7)))
                }
                .transition(.scale.combined(with: .opacity))
            }

            // Main controls row
            HStack(spacing: 40) {
                // Current zoom display
                Text("\(String(format: "%.1f", viewModel.currentZoomFactor))x")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 50)

                // Shutter button
                shutterButton()

                // Ai toggle button
                aiToggleButton()
            }
        }
    }

    // MARK: - Shutter Button

    @ViewBuilder
    private func shutterButton() -> some View {
        Button {
            viewModel.capturePhoto()
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 72, height: 72)

                Circle()
                    .fill(Color.white)
                    .frame(width: 62, height: 62)
            }
        }
        .scaleEffect(viewModel.isAligned && viewModel.isAlignmentModeOn ? 1.08 : 1.0)
        .shadow(
            color: viewModel.isAligned && viewModel.isAlignmentModeOn
                ? Color.accentColor.opacity(0.6) : .clear,
            radius: 10
        )
        .animation(
            viewModel.isAligned
                ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                : .default,
            value: viewModel.isAligned
        )
    }

    // MARK: - Ai Toggle

    @ViewBuilder
    private func aiToggleButton() -> some View {
        Button {
            viewModel.toggleAlignmentMode()
        } label: {
            Text("Ai")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(viewModel.isAlignmentModeOn ? .black : .white)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(viewModel.isAlignmentModeOn ? Color.yellow : Color.white.opacity(0.2))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        }
    }

    // MARK: - Alignment Border (rainbow gradient when not aligned, solid when aligned)

    @ViewBuilder
    private func alignmentBorder(size: CGSize) -> some View {
        if viewModel.isAligned {
            // Solid accent border
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.accentColor, lineWidth: 4)
                .ignoresSafeArea()
                .transition(.opacity)
        } else {
            // Animated rainbow gradient border
            RoundedRectangle(cornerRadius: 0)
                .stroke(
                    AngularGradient(
                        colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red],
                        center: .center
                    ),
                    lineWidth: 4
                )
                .ignoresSafeArea()
                .transition(.opacity)
        }
    }

    // MARK: - Target Dot (white circle at target composition point)

    @ViewBuilder
    private func targetDot(target: CGPoint, size: CGSize) -> some View {
        let screenPoint = visionToScreen(target, in: size)

        ZStack {
            // Outer ring
            Circle()
                .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                .frame(width: 40, height: 40)

            // Crosshair lines
            Rectangle()
                .fill(Color.white.opacity(0.4))
                .frame(width: 1, height: 20)
            Rectangle()
                .fill(Color.white.opacity(0.4))
                .frame(width: 20, height: 1)

            // Center dot
            Circle()
                .fill(Color.white)
                .frame(width: 6, height: 6)
        }
        .position(x: screenPoint.x, y: screenPoint.y)
    }

    // MARK: - Subject Indicator (small colored dot at current detected subject)

    @ViewBuilder
    private func subjectIndicator(subject: CGPoint, size: CGSize) -> some View {
        let screenPoint = visionToScreen(subject, in: size)

        Circle()
            .fill(viewModel.isAligned ? Color.green : Color.orange)
            .frame(width: 10, height: 10)
            .shadow(color: viewModel.isAligned ? .green : .orange, radius: 4)
            .position(x: screenPoint.x, y: screenPoint.y)
            .animation(.easeOut(duration: 0.15), value: subject.x)
            .animation(.easeOut(duration: 0.15), value: subject.y)
    }

    // MARK: - Captured Photo Overlay

    @ViewBuilder
    private func capturedPhotoOverlay(image: UIImage) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .ignoresSafeArea()

            VStack {
                Spacer()

                HStack(spacing: 30) {
                    // Dismiss
                    Button {
                        viewModel.showCapturedPhoto = false
                        viewModel.capturedImage = nil
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.left")
                            Text("Back")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.white.opacity(0.2)))
                    }

                    // Saved indicator
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Saved to Photos")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.green)
                }
                .padding(.bottom, 50)
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: viewModel.showCapturedPhoto)
    }

    // MARK: - No Camera Access

    @ViewBuilder
    private func noCameraAccessView() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("Camera Access Required")
                .font(.title3.bold())
                .foregroundColor(.white)

            Text("Please enable camera access in Settings to use AI Compose Camera.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.blue)
            .padding(.top, 8)
        }
    }

    // MARK: - Coordinate Helpers

    /// Convert Vision normalized coordinates (bottom-left origin) to screen coordinates (top-left origin).
    private func visionToScreen(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: point.x * size.width,
            y: (1 - point.y) * size.height
        )
    }
}

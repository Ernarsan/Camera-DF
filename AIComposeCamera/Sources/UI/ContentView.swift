import SwiftUI

/// Main screen: full-screen camera preview with multi-mode UI (Photo, Video, 360° Panorama),
/// authentic Y2K CCD retro camera viewfinder HUD, 7 camera profiles, AI overlays, and USB export.
struct ContentView: View {

    @StateObject private var viewModel = CameraViewModel()
    @State private var shutterFlashOpacity: Double = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // MARK: - 1. Base Viewfinder (Full Screen)
                Color.black.ignoresSafeArea()

                CameraPreviewView(session: viewModel.captureSession)
                    .ignoresSafeArea()

                // MARK: - 2. Shutter Flash Effect
                Color.white
                    .opacity(shutterFlashOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                // MARK: - 3. Rule of Thirds Grid Overlay
                if viewModel.showGrid && viewModel.currentMode == .photo {
                    gridOverlay(size: geometry.size)
                        .allowsHitTesting(false)
                }

                // MARK: - 4. Active Mode UI Layer
                switch viewModel.currentMode {
                case .photo:
                    photoModeOverlay(size: geometry.size)
                case .video:
                    videoModeOverlay()
                case .panorama:
                    panoramaModeOverlay()
                }

                // MARK: - 5. Timer Countdown Overlay (Center Screen)
                if let count = viewModel.timerCountdown {
                    timerCountdownView(count: count)
                }

                // MARK: - 6. Captured Photo Preview (Save / Share / Export to USB)
                if viewModel.showCapturedPhoto, let image = viewModel.capturedImage {
                    PhotoPreviewView(
                        image: image,
                        filterName: viewModel.selectedCamera.displayName,
                        onDismiss: {
                            viewModel.showCapturedPhoto = false
                            viewModel.capturedImage = nil
                        },
                        onSave: {
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                        },
                        onShare: {
                            viewModel.shareImage(image)
                        },
                        onExportExternal: {
                            viewModel.exportToExternal(image: image)
                        }
                    )
                    .transition(.opacity)
                }

                // MARK: - 7. No Camera Access View
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
            if viewModel.currentMode == .panorama {
                viewModel.panoramaManager.stopSession()
            }
        }
        .onChange(of: viewModel.currentMode) { newMode in
            if viewModel.videoRecorder.isRecording {
                viewModel.videoRecorder.stopRecording()
            }
            if newMode == .panorama {
                viewModel.panoramaManager.startSession()
            } else {
                viewModel.panoramaManager.stopSession()
            }
        }
    }

    // MARK: - Photo Mode Overlay

    @ViewBuilder
    private func photoModeOverlay(size: CGSize) -> some View {
        ZStack {
            // Retro LCD Viewfinder HUD (battery, frame counter, aspect ratio, glowing date stamp)
            RetroViewfinderHUD(
                camera: viewModel.selectedCamera,
                aspectRatio: viewModel.selectedAspectRatio,
                isDateStampOn: viewModel.isDateStampEnabled,
                isGrainOn: viewModel.isGrainEnabled,
                photoCount: viewModel.sessionPhotoCount,
                flashMode: viewModel.flashMode,
                containerSize: size
            )

            // Alignment Mode Border
            if viewModel.isAlignmentModeOn {
                alignmentBorder(size: size)
            }

            // Saliency Box (Standard Mode)
            if let box = viewModel.suggestedBox, !viewModel.isAlignmentModeOn {
                SaliencyBoxView(box: box, containerSize: size)
            }

            // Alignment Target Dot
            if viewModel.isAlignmentModeOn, let target = viewModel.targetCompositionPoint {
                targetDot(target: target, size: size)
            }

            // Current Subject Point
            if viewModel.isAlignmentModeOn, let subject = viewModel.currentSubjectPoint {
                subjectIndicator(subject: subject, size: size)
            }

            // Controls Stack
            VStack {
                // Top: Controls (Flash, Ratio, Date, Grain, Timer, Grid)
                TopControlsView(
                    flashMode: $viewModel.flashMode,
                    isHDR: $viewModel.isHDR,
                    timerDuration: $viewModel.timerDuration,
                    showGrid: $viewModel.showGrid,
                    aspectRatio: $viewModel.selectedAspectRatio,
                    isDateStampEnabled: $viewModel.isDateStampEnabled,
                    isGrainEnabled: $viewModel.isGrainEnabled
                )
                .padding(.top, 50)

                // Top AI Suggestion Bubbles
                topBubbles()
                    .padding(.top, 6)

                Spacer()

                // Smart Suggested Zoom Pill
                if let zoom = viewModel.suggestedZoom, zoom > 1, !viewModel.isAlignmentModeOn {
                    Button {
                        viewModel.applyZoom()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.magnifyingglass")
                            Text("AI Zoom \(Int(zoom))x")
                                .fontWeight(.semibold)
                        }
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.blue.opacity(0.85)))
                    }
                    .transition(.scale.combined(with: .opacity))
                    .padding(.bottom, 6)
                }

                // Retro Camera Selector Carousel (CCD, G7X, NOKIA, LOMO, XT30, DV, POLA)
                CameraWheelPickerView(selectedCamera: $viewModel.selectedCamera)
                    .padding(.bottom, 10)

                // Zoom Factors Row (0.5x, 1x, 2x, 5x, 10x)
                zoomRow
                    .padding(.bottom, 14)

                // Shutter Row (Gallery counter, Shutter, AI toggle, Flip)
                photoControlRow
                    .padding(.bottom, 12)

                // Mode Picker (PHOTO | VIDEO | 360°)
                ModePickerView(selectedMode: $viewModel.currentMode)
                    .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Video Mode Overlay

    @ViewBuilder
    private func videoModeOverlay() -> some View {
        VStack {
            VideoControlsView(
                isRecording: viewModel.videoRecorder.isRecording,
                recordingDuration: viewModel.videoRecorder.recordingDuration,
                currentZoom: viewModel.currentZoomFactor,
                flashEnabled: viewModel.flashMode == .on,
                supportsUltraWide: viewModel.supportsUltraWide,
                onToggleRecording: {
                    viewModel.toggleVideoRecording()
                },
                onFlipCamera: {
                    viewModel.flipCamera()
                },
                onToggleFlash: {
                    viewModel.toggleTorch()
                },
                onZoomTap: { factor in
                    viewModel.setZoomFactor(factor)
                },
                onBack: {
                    viewModel.currentMode = .photo
                }
            )

            if !viewModel.videoRecorder.isRecording {
                ModePickerView(selectedMode: $viewModel.currentMode)
                    .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Panorama Mode Overlay

    @ViewBuilder
    private func panoramaModeOverlay() -> some View {
        VStack {
            PanoramaView(
                manager: viewModel.panoramaManager,
                onCapture: {
                    triggerFlash()
                    viewModel.capturePanoramaFrame()
                },
                onBack: {
                    viewModel.panoramaManager.reset()
                    viewModel.currentMode = .photo
                },
                onSaveAll: {
                    viewModel.panoramaManager.saveAllToLibrary()
                    viewModel.panoramaManager.reset()
                    viewModel.currentMode = .photo
                }
            )

            ModePickerView(selectedMode: $viewModel.currentMode)
                .padding(.bottom, 16)
        }
    }

    // MARK: - Top Bubbles

    @ViewBuilder
    private func topBubbles() -> some View {
        VStack(spacing: 8) {
            if viewModel.isAnalyzing && !viewModel.isAlignmentModeOn {
                SuggestionBubbleView.analyzing
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if !viewModel.filterName.isEmpty && !viewModel.isAnalyzing && !viewModel.isAlignmentModeOn {
                SuggestionBubbleView.filterRecommendation(
                    name: viewModel.filterName,
                    reason: viewModel.filterReason
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if viewModel.isAlignmentModeOn && !viewModel.alignmentInstruction.isEmpty {
                SuggestionBubbleView.alignment(instruction: viewModel.alignmentInstruction)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if viewModel.isLowLight && !viewModel.isAlignmentModeOn {
                HStack(spacing: 6) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                    Text("Night Boost Active")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(.ultraThinMaterial).environment(\.colorScheme, .dark))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isAnalyzing)
        .animation(.easeInOut(duration: 0.3), value: viewModel.filterName)
        .animation(.easeInOut(duration: 0.3), value: viewModel.alignmentInstruction)
    }

    // MARK: - Zoom Row

    private var zoomRow: some View {
        let factors: [CGFloat] = viewModel.supportsUltraWide ? [0.5, 1.0, 2.0, 5.0, 10.0] : [1.0, 2.0, 5.0, 10.0]
        return HStack(spacing: 8) {
            ForEach(factors, id: \.self) { factor in
                Button {
                    viewModel.setZoomFactor(factor)
                } label: {
                    Text(factor == 0.5 ? "0.5x" : "\(Int(factor))x")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(
                            abs(viewModel.currentZoomFactor - factor) < 0.1
                                ? .white
                                : .white.opacity(0.6)
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(
                                abs(viewModel.currentZoomFactor - factor) < 0.1
                                    ? viewModel.selectedCamera.accentColor
                                    : Color.white.opacity(0.12)
                            )
                        )
                }
            }
        }
    }

    // MARK: - Photo Controls Row

    private var photoControlRow: some View {
        HStack(spacing: 24) {
            // Photo count / Gallery badge
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .frame(width: 48, height: 48)

                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 20))
                    .foregroundColor(.white)

                if viewModel.sessionPhotoCount > 0 {
                    Text("\(viewModel.sessionPhotoCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Circle().fill(viewModel.selectedCamera.accentColor))
                        .offset(x: 14, y: -14)
                }
            }

            Spacer()

            // Shutter button (Mechanical styling with camera accent color)
            shutterButton()

            Spacer()

            // Ai alignment mode toggle button
            aiToggleButton()

            // Flip camera button
            Button {
                viewModel.flipCamera()
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .frame(width: 48, height: 48)

                    Image(systemName: "camera.rotate.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Shutter Button

    @ViewBuilder
    private func shutterButton() -> some View {
        Button {
            triggerFlash()
            viewModel.capturePhoto()
        } label: {
            ZStack {
                // Outer chrome ring
                Circle()
                    .stroke(
                        viewModel.isAligned && viewModel.isAlignmentModeOn
                            ? Color.green
                            : Color.white.opacity(0.85),
                        lineWidth: 4
                    )
                    .frame(width: 74, height: 74)

                // Inner tactile button
                Circle()
                    .fill(
                        viewModel.isAlignmentModeOn
                            ? (viewModel.isAligned ? Color.green : Color.yellow)
                            : viewModel.selectedCamera.accentColor
                    )
                    .frame(width: 58, height: 58)
                    .shadow(color: viewModel.selectedCamera.accentColor.opacity(0.6), radius: 6)

                // Retro shutter concentric detail
                Circle()
                    .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                    .frame(width: 46, height: 46)
            }
        }
        .scaleEffect(viewModel.isAligned && viewModel.isAlignmentModeOn ? 1.08 : 1.0)
        .animation(
            viewModel.isAligned
                ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                : .default,
            value: viewModel.isAligned
        )
    }

    // MARK: - Ai Toggle Button

    @ViewBuilder
    private func aiToggleButton() -> some View {
        Button {
            viewModel.toggleAlignmentMode()
        } label: {
            ZStack {
                Circle()
                    .fill(viewModel.isAlignmentModeOn ? Color.yellow : Color.white.opacity(0.18))
                    .frame(width: 48, height: 48)

                Text("Ai")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(viewModel.isAlignmentModeOn ? .black : .white)
            }
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Timer Countdown Overlay

    @ViewBuilder
    private func timerCountdownView(count: Int) -> some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()

            Text("\(count)")
                .font(.system(size: 110, weight: .thin, design: .rounded))
                .foregroundColor(.white)
                .scaleEffect(1.1)
                .animation(.easeInOut(duration: 0.3), value: count)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Grid Overlay (Rule of Thirds)

    @ViewBuilder
    private func gridOverlay(size: CGSize) -> some View {
        ZStack {
            // Horizontal lines
            Path { path in
                let y1 = size.height / 3.0
                let y2 = (size.height * 2.0) / 3.0
                path.move(to: CGPoint(x: 0, y: y1))
                path.addLine(to: CGPoint(x: size.width, y: y1))
                path.move(to: CGPoint(x: 0, y: y2))
                path.addLine(to: CGPoint(x: size.width, y: y2))
            }
            .stroke(Color.white.opacity(0.28), lineWidth: 0.75)

            // Vertical lines
            Path { path in
                let x1 = size.width / 3.0
                let x2 = (size.width * 2.0) / 3.0
                path.move(to: CGPoint(x: x1, y: 0))
                path.addLine(to: CGPoint(x: x1, y: size.height))
                path.move(to: CGPoint(x: x2, y: 0))
                path.addLine(to: CGPoint(x: x2, y: size.height))
            }
            .stroke(Color.white.opacity(0.28), lineWidth: 0.75)
        }
    }

    // MARK: - Alignment Border

    @ViewBuilder
    private func alignmentBorder(size: CGSize) -> some View {
        if viewModel.isAligned {
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.green, lineWidth: 4)
                .ignoresSafeArea()
                .transition(.opacity)
        } else {
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

    // MARK: - Target Dot

    @ViewBuilder
    private func targetDot(target: CGPoint, size: CGSize) -> some View {
        let screenPoint = visionToScreen(target, in: size)

        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.7), lineWidth: 1.5)
                .frame(width: 42, height: 42)

            Rectangle()
                .fill(Color.white.opacity(0.5))
                .frame(width: 1, height: 22)
            Rectangle()
                .fill(Color.white.opacity(0.5))
                .frame(width: 22, height: 1)

            Circle()
                .fill(Color.white)
                .frame(width: 6, height: 6)
        }
        .position(x: screenPoint.x, y: screenPoint.y)
    }

    // MARK: - Subject Indicator

    @ViewBuilder
    private func subjectIndicator(subject: CGPoint, size: CGSize) -> some View {
        let screenPoint = visionToScreen(subject, in: size)

        Circle()
            .fill(viewModel.isAligned ? Color.green : Color.orange)
            .frame(width: 12, height: 12)
            .shadow(color: viewModel.isAligned ? .green : .orange, radius: 5)
            .position(x: screenPoint.x, y: screenPoint.y)
            .animation(.easeOut(duration: 0.15), value: subject.x)
            .animation(.easeOut(duration: 0.15), value: subject.y)
    }

    // MARK: - No Camera Access

    @ViewBuilder
    private func noCameraAccessView() -> some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 54))
                    .foregroundColor(.gray)

                Text("Camera Access Required")
                    .font(.title2.bold())
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
                .padding(.top, 10)
            }
        }
    }

    // MARK: - Helpers

    private func triggerFlash() {
        withAnimation(.linear(duration: 0.05)) {
            shutterFlashOpacity = 0.85
        }
        withAnimation(.easeOut(duration: 0.25).delay(0.06)) {
            shutterFlashOpacity = 0
        }
    }

    private func visionToScreen(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: point.x * size.width,
            y: (1 - point.y) * size.height
        )
    }
}

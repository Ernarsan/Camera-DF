import AudioToolbox
import AVFoundation
import Combine
import CoreImage
import Photos
import SwiftUI
import UIKit

// MARK: - Thread-Safe Analysis State

private final class AnalysisCoordinator: @unchecked Sendable {
    private let lock = NSLock()
    private var _mode: CameraMode = .photo
    private var _isAlignmentOn: Bool = false
    private var _lastAnalysisTime: CFAbsoluteTime = 0

    var mode: CameraMode {
        get { lock.withLock { _mode } }
        set { lock.withLock { _mode = newValue } }
    }

    var isAlignmentOn: Bool {
        get { lock.withLock { _isAlignmentOn } }
        set { lock.withLock { _isAlignmentOn = newValue } }
    }

    func shouldAnalyze(now: CFAbsoluteTime, interval: CFTimeInterval) -> Bool {
        lock.withLock {
            if now - _lastAnalysisTime >= interval {
                _lastAnalysisTime = now
                return true
            }
            return false
        }
    }
}

// MARK: - CameraViewModel

@MainActor
final class CameraViewModel: NSObject, ObservableObject {

    // MARK: - App Mode

    @Published var currentMode: CameraMode = .photo {
        didSet {
            analysisCoordinator.mode = currentMode
        }
    }

    // MARK: - Hardware Capabilities

    @Published var supportsUltraWide: Bool = false

    // MARK: - Retro / Kapi Cam State

    @Published var selectedCamera: RetroCameraProfile = .ccd
    @Published var isDateStampEnabled: Bool = true
    @Published var isGrainEnabled: Bool = true
    @Published var selectedAspectRatio: AspectRatioMode = .ratio4_3
    @Published var dateStyle: RetroDateStamper.DateStyle = .currentYear

    // MARK: - Published State (Composition Analysis)

    @Published var isAnalyzing: Bool = false
    @Published var suggestedBox: CGRect?
    @Published var suggestedZoom: CGFloat?
    @Published var sceneDescription: String = ""
    @Published var filterName: String = ""
    @Published var filterReason: String = ""
    @Published var capturedImage: UIImage?
    @Published var currentZoomFactor: CGFloat = 1.0

    // Alignment Guide
    @Published var targetCompositionPoint: CGPoint?
    @Published var currentSubjectPoint: CGPoint?
    @Published var isAligned: Bool = false
    @Published var alignmentInstruction: String = ""

    // Night Enhancer
    @Published var isLowLight: Bool = false

    // UI State
    @Published var isAlignmentModeOn: Bool = false {
        didSet {
            analysisCoordinator.isAlignmentOn = isAlignmentModeOn
        }
    }
    @Published var isCameraAuthorized: Bool = false
    @Published var showCapturedPhoto: Bool = false

    // Camera Controls
    @Published var flashMode: FlashMode = .off
    @Published var isHDR: Bool = false
    @Published var timerDuration: TimerDuration = .off
    @Published var showGrid: Bool = false
    @Published var cameraPosition: AVCaptureDevice.Position = .back

    // Timer countdown
    @Published var timerCountdown: Int? = nil
    private var countdownTask: Task<Void, Never>?

    // Video Recording
    @Published var videoRecorder: VideoRecorder

    // Panorama
    @Published var panoramaManager = PanoramaManager()

    // Session Photo Count
    @Published var sessionPhotoCount: Int = 0

    // MARK: - Session & Outputs

    nonisolated let captureSession = AVCaptureSession()
    nonisolated private let photoOutput = AVCapturePhotoOutput()
    nonisolated private let videoDataOutput = AVCaptureVideoDataOutput()
    nonisolated let movieOutput = AVCaptureMovieFileOutput()
    nonisolated private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - Queues

    nonisolated private let sessionQueue = DispatchQueue(label: "com.aicompose.camera.session")
    nonisolated private let analysisQueue = DispatchQueue(label: "com.aicompose.camera.analysis", qos: .userInitiated)

    // MARK: - Thread-safe Analysis Coordinator

    nonisolated private let analysisCoordinator = AnalysisCoordinator()

    // MARK: - Cancellables

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Throttling Intervals

    nonisolated private let compositionThrottleInterval: CFTimeInterval = 0.5
    nonisolated private let alignmentThrottleInterval: CFTimeInterval = 0.25

    // MARK: - Device

    private var currentDevice: AVCaptureDevice?
    private var currentInput: AVCaptureDeviceInput?
    private var isUsingUltraWide: Bool = false

    // MARK: - Init

    override init() {
        let output = movieOutput
        self.videoRecorder = VideoRecorder(movieOutput: output)
        super.init()

        // Check ultra-wide hardware availability
        self.supportsUltraWide = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) != nil

        videoRecorder.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        panoramaManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    /// Request camera permission and configure the session.
    func start() {
        Task {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            switch status {
            case .authorized:
                isCameraAuthorized = true
            case .notDetermined:
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                isCameraAuthorized = granted
            default:
                isCameraAuthorized = false
                return
            }

            guard isCameraAuthorized else { return }
            configureSession()
        }
    }

    /// Stop the capture session.
    func stop() {
        countdownTask?.cancel()
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }

    /// Apply the suggested zoom factor to the camera device.
    func applyZoom() {
        guard let zoom = suggestedZoom else { return }
        setZoomFactor(zoom)
    }

    /// Set a specific zoom factor (0.5x, 1x, 2x, 5x, 10x).
    func setZoomFactor(_ factor: CGFloat) {
        if factor <= 0.75 {
            // Ultra-wide lens requested
            switchToUltraWide()
        } else {
            // Standard wide lens requested with digital zoom
            switchToWide(zoomFactor: factor)
        }
    }

    private func switchToUltraWide() {
        guard cameraPosition == .back else { return }
        guard let ultraWideDevice = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) else {
            // Fallback: stay on current device
            return
        }

        if isUsingUltraWide && currentDevice?.deviceType == .builtInUltraWideCamera {
            currentZoomFactor = 0.5
            return
        }

        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.beginConfiguration()

            // Remove existing video inputs
            for input in self.captureSession.inputs {
                if let devInput = input as? AVCaptureDeviceInput, devInput.device.hasMediaType(.video) {
                    self.captureSession.removeInput(devInput)
                }
            }

            guard let newInput = try? AVCaptureDeviceInput(device: ultraWideDevice) else {
                self.captureSession.commitConfiguration()
                return
            }

            if self.captureSession.canAddInput(newInput) {
                self.captureSession.addInput(newInput)
            }

            self.configureOutputOrientations()
            self.captureSession.commitConfiguration()

            Task { @MainActor [weak self] in
                self?.currentDevice = ultraWideDevice
                self?.currentInput = newInput
                self?.isUsingUltraWide = true
                self?.currentZoomFactor = 0.5
            }
        }
    }

    private func switchToWide(zoomFactor: CGFloat) {
        let wideDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition)
        guard let device = wideDevice else { return }

        let needsDeviceSwitch = isUsingUltraWide || currentDevice != device

        if needsDeviceSwitch {
            sessionQueue.async { [weak self] in
                guard let self = self else { return }
                self.captureSession.beginConfiguration()

                // Remove existing video inputs
                for input in self.captureSession.inputs {
                    if let devInput = input as? AVCaptureDeviceInput, devInput.device.hasMediaType(.video) {
                        self.captureSession.removeInput(devInput)
                    }
                }

                guard let newInput = try? AVCaptureDeviceInput(device: device) else {
                    self.captureSession.commitConfiguration()
                    return
                }

                if self.captureSession.canAddInput(newInput) {
                    self.captureSession.addInput(newInput)
                }

                self.configureOutputOrientations()

                // Apply zoom factor
                let clamped = min(max(zoomFactor, 1.0), device.activeFormat.videoMaxZoomFactor)
                do {
                    try device.lockForConfiguration()
                    device.videoZoomFactor = clamped
                    device.unlockForConfiguration()
                } catch {
                    print("[CameraVM] Zoom configuration error: \(error)")
                }

                self.captureSession.commitConfiguration()

                Task { @MainActor [weak self] in
                    self?.currentDevice = device
                    self?.currentInput = newInput
                    self?.isUsingUltraWide = false
                    self?.currentZoomFactor = clamped
                }
            }
        } else {
            // Same device, just update zoom factor
            let clamped = min(max(zoomFactor, 1.0), device.activeFormat.videoMaxZoomFactor)
            sessionQueue.async { [weak self] in
                do {
                    try device.lockForConfiguration()
                    device.videoZoomFactor = clamped
                    device.unlockForConfiguration()
                    Task { @MainActor [weak self] in
                        self?.currentZoomFactor = clamped
                    }
                } catch {
                    print("[CameraVM] Zoom error: \(error)")
                }
            }
        }
    }

    /// Toggle alignment mode (Ai button).
    func toggleAlignmentMode() {
        isAlignmentModeOn.toggle()
        if isAlignmentModeOn {
            alignmentInstruction = "Ai Detecting the scene. Keep your phone still."
            targetCompositionPoint = nil
            currentSubjectPoint = nil
            isAligned = false
        } else {
            targetCompositionPoint = nil
            currentSubjectPoint = nil
            isAligned = false
            alignmentInstruction = ""
        }
    }

    /// Switch between front and back camera.
    func flipCamera() {
        let newPosition: AVCaptureDevice.Position = (cameraPosition == .back) ? .front : .back
        cameraPosition = newPosition
        supportsUltraWide = (newPosition == .back) && (AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) != nil)

        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.beginConfiguration()

            // Remove ONLY video inputs, leaving audio input intact!
            for input in self.captureSession.inputs {
                if let devInput = input as? AVCaptureDeviceInput, devInput.device.hasMediaType(.video) {
                    self.captureSession.removeInput(devInput)
                }
            }

            // Add new video input
            let deviceType: AVCaptureDevice.DeviceType = .builtInWideAngleCamera
            guard let device = AVCaptureDevice.default(deviceType, for: .video, position: newPosition),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                self.captureSession.commitConfiguration()
                return
            }

            if self.captureSession.canAddInput(input) {
                self.captureSession.addInput(input)
            }

            self.configureOutputOrientations()
            self.captureSession.commitConfiguration()

            Task { @MainActor [weak self] in
                self?.currentDevice = device
                self?.currentInput = input
                self?.isUsingUltraWide = false
                self?.currentZoomFactor = 1.0
            }
        }
    }

    /// Toggle the torch (flashlight) for video mode.
    func toggleTorch() {
        guard let device = currentDevice, device.hasTorch else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.torchMode = device.torchMode == .on ? .off : .on
                device.unlockForConfiguration()
            } catch {
                print("[CameraVM] Torch error: \(error)")
            }
        }
    }

    // MARK: - Photo Capture

    /// Capture a photo with optional timer delay.
    func capturePhoto() {
        if timerDuration != .off && timerCountdown == nil {
            startTimerCountdown(seconds: timerDuration.seconds)
            return
        }
        doCapture()
    }

    private func startTimerCountdown(seconds: Int) {
        countdownTask?.cancel()
        countdownTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.timerCountdown = seconds

            for remaining in stride(from: seconds - 1, through: 1, by: -1) {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                self.timerCountdown = remaining
            }

            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            self.timerCountdown = nil
            self.doCapture()
        }
    }

    private func doCapture() {
        let settings = AVCapturePhotoSettings()

        // Flash mode
        switch flashMode {
        case .off:
            settings.flashMode = .off
        case .on:
            settings.flashMode = .on
        case .auto:
            settings.flashMode = .auto
        }

        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - Video Recording

    /// Start or stop video recording.
    func toggleVideoRecording() {
        if videoRecorder.isRecording {
            videoRecorder.stopRecording()
        } else {
            videoRecorder.startRecording()
        }
    }

    // MARK: - Panorama

    /// Capture panorama photo at current position.
    func capturePanoramaFrame() {
        guard panoramaManager.nearbyPointIndex != nil else { return }

        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - Export to External Storage

    /// Export image data to external storage via UIDocumentPickerViewController.
    func exportToExternal(image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.92) else { return }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AIComposeCamera_\(Int(Date().timeIntervalSince1970)).jpg")

        do {
            try data.write(to: tempURL)
        } catch {
            print("[CameraVM] Export write error: \(error)")
            return
        }

        // Present document picker via scene
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        let picker = UIDocumentPickerViewController(forExporting: [tempURL], asCopy: true)
        rootVC.present(picker, animated: true)
    }

    /// Share image via system share sheet.
    func shareImage(_ image: UIImage) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        rootVC.present(activityVC, animated: true)
    }

    // MARK: - Session Configuration

    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.beginConfiguration()

            if self.captureSession.canSetSessionPreset(.high) {
                self.captureSession.sessionPreset = .high
            } else {
                self.captureSession.sessionPreset = .photo
            }

            // Audio input for video recording
            if let audioDevice = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: audioDevice) {
                if self.captureSession.canAddInput(audioInput) {
                    self.captureSession.addInput(audioInput)
                }
            }

            // Video input — back wide camera initially
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                self.captureSession.commitConfiguration()
                return
            }

            if self.captureSession.canAddInput(input) {
                self.captureSession.addInput(input)
            }

            Task { @MainActor [weak self] in
                self?.currentDevice = device
                self?.currentInput = input
                self?.isUsingUltraWide = false
            }

            // Video data output (for real-time AI frame analysis)
            self.videoDataOutput.setSampleBufferDelegate(self, queue: self.analysisQueue)
            self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
            if self.captureSession.canAddOutput(self.videoDataOutput) {
                self.captureSession.addOutput(self.videoDataOutput)
            }

            // Photo output
            if self.captureSession.canAddOutput(self.photoOutput) {
                self.captureSession.addOutput(self.photoOutput)
            }

            // Video recorder output
            if self.captureSession.canAddOutput(self.movieOutput) {
                self.captureSession.addOutput(self.movieOutput)
            }

            self.configureOutputOrientations()
            self.captureSession.commitConfiguration()
            self.captureSession.startRunning()
        }
    }

    nonisolated private func configureOutputOrientations() {
        if let videoConnection = videoDataOutput.connection(with: .video), videoConnection.isVideoOrientationSupported {
            videoConnection.videoOrientation = .portrait
        }
        if let movieConnection = movieOutput.connection(with: .video), movieConnection.isVideoOrientationSupported {
            movieConnection.videoOrientation = .portrait
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CFAbsoluteTimeGetCurrent()

        // 1. Thread-safe fast check: mode and throttling
        guard analysisCoordinator.mode == .photo else { return }

        let isAlignment = analysisCoordinator.isAlignmentOn
        let interval = isAlignment ? alignmentThrottleInterval : compositionThrottleInterval

        guard analysisCoordinator.shouldAnalyze(now: now, interval: interval) else { return }

        // 2. Synchronously obtain pixel buffer while sample buffer is guaranteed valid
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // 3. Process on analysisQueue directly (no task deferral!)
        if isAlignment {
            let guidance = AlignmentGuide.evaluate(pixelBuffer: pixelBuffer, orientation: .up)
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.targetCompositionPoint = guidance.targetPoint
                self.currentSubjectPoint = guidance.currentSubjectPoint
                self.isAligned = guidance.isAligned
                self.alignmentInstruction = guidance.instruction
            }
        } else {
            Task { @MainActor [weak self] in
                self?.isAnalyzing = true
            }

            let composition = CompositionAnalyzer.analyze(pixelBuffer: pixelBuffer, orientation: .up)
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let recommendation = SceneFilterRecommender.recommend(for: ciImage, context: self.ciContext)

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.suggestedBox = composition.saliencyBox
                self.suggestedZoom = composition.suggestedZoom
                self.sceneDescription = recommendation.sceneDescription
                self.filterName = recommendation.filterName
                self.filterReason = recommendation.reason
                self.isLowLight = (recommendation.filterName == "Night Boost")
                self.isAnalyzing = false
            }
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraViewModel: AVCapturePhotoCaptureDelegate {

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let rawImage = UIImage(data: data) else {
            print("[CameraVM] Photo capture error: \(error?.localizedDescription ?? "unknown")")
            return
        }

        Task { @MainActor [weak self] in
            guard let self = self else { return }

            // Check if this is a panorama capture
            if self.currentMode == .panorama {
                self.panoramaManager.captureAtCurrentPosition(imageData: data)
                return
            }

            // Shutter sound & heavy tactile mechanical feedback
            AudioServicesPlaySystemSound(1108)
            let haptic = UIImpactFeedbackGenerator(style: .heavy)
            haptic.impactOccurred()

            // 1. Apply Retro Filter Engine (CCD / G7X / Nokia / Lomo / XT30 / DV / Pola)
            var finalImage = RetroFilterEngine.shared.process(
                image: rawImage,
                profile: self.selectedCamera,
                includeGrain: self.isGrainEnabled
            )

            // 2. Apply Night Boost if scene is dark
            if self.isLowLight {
                let nightResult = NightEnhancer.enhanceIfNeeded(finalImage)
                if nightResult.isLowLight, let enhanced = nightResult.enhancedImage {
                    finalImage = enhanced
                }
            }

            // 3. Stamp Y2K Digital Date if enabled
            if self.isDateStampEnabled {
                finalImage = RetroDateStamper.stamp(
                    image: finalImage,
                    profile: self.selectedCamera,
                    style: self.dateStyle
                )
            }

            // 4. Show captured image in preview
            self.capturedImage = finalImage
            self.showCapturedPhoto = true
            self.sessionPhotoCount += 1

            // 5. Save to Photos
            self.saveToPhotoLibrary(finalImage)
        }
    }

    private func saveToPhotoLibrary(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                print("[CameraVM] Photo library access denied")
                return
            }

            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                if success {
                    print("[CameraVM] Photo saved to library")
                } else {
                    print("[CameraVM] Save error: \(error?.localizedDescription ?? "unknown")")
                }
            }
        }
    }
}

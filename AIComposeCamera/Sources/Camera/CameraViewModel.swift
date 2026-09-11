import AVFoundation
import Combine
import CoreImage
import Photos
import SwiftUI
import UIKit

/// Central view model that manages camera session, frame analysis,
/// photo/video capture, mode switching, and publishes all state for the UI.
@MainActor
final class CameraViewModel: NSObject, ObservableObject {

    // MARK: - App Mode

    @Published var currentMode: CameraMode = .photo

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
    @Published var isAlignmentModeOn: Bool = false
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

    // MARK: - Cancellables

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Throttling

    private var lastAnalysisTime: CFAbsoluteTime = 0
    private let compositionThrottleInterval: CFTimeInterval = 0.6
    private let alignmentThrottleInterval: CFTimeInterval = 0.3

    // MARK: - Device

    private var currentDevice: AVCaptureDevice?
    private var currentInput: AVCaptureDeviceInput?

    // MARK: - Init

    override init() {
        let output = movieOutput
        self.videoRecorder = VideoRecorder(movieOutput: output)
        super.init()

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
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }

    /// Apply the suggested zoom factor to the camera device.
    func applyZoom() {
        guard let device = currentDevice, let zoom = suggestedZoom else { return }
        setZoomFactor(zoom, on: device)
    }

    /// Set a specific zoom factor.
    func setZoomFactor(_ factor: CGFloat) {
        guard let device = currentDevice else { return }
        setZoomFactor(factor, on: device)
    }

    private func setZoomFactor(_ factor: CGFloat, on device: AVCaptureDevice) {
        let clamped = min(max(factor, 1.0), device.activeFormat.videoMaxZoomFactor)
        sessionQueue.async {
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

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.captureSession.beginConfiguration()

            // Remove current input
            if let currentInput = self.captureSession.inputs.first as? AVCaptureDeviceInput {
                self.captureSession.removeInput(currentInput)
            }

            // Add new input
            let deviceType: AVCaptureDevice.DeviceType = .builtInWideAngleCamera
            guard let device = AVCaptureDevice.default(deviceType, for: .video, position: newPosition),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                self.captureSession.commitConfiguration()
                return
            }

            if self.captureSession.canAddInput(input) {
                self.captureSession.addInput(input)
            }

            self.captureSession.commitConfiguration()

            Task { @MainActor [weak self] in
                self?.currentDevice = device
                self?.currentInput = input
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
            // Start countdown
            timerCountdown = timerDuration.seconds
            startTimerCountdown()
            return
        }
        doCapture()
    }

    private func startTimerCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self else {
                    timer.invalidate()
                    return
                }
                if let current = self.timerCountdown {
                    if current <= 1 {
                        timer.invalidate()
                        self.timerCountdown = nil
                        self.doCapture()
                    } else {
                        self.timerCountdown = current - 1
                    }
                }
            }
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

        // We'll use a special flag to know this is a panorama capture
        // For simplicity, we capture via the photo output and handle in delegate
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
            guard let self else { return }
            self.captureSession.beginConfiguration()
            if captureSession.canSetSessionPreset(.high) {
                captureSession.sessionPreset = .high
            } else {
                captureSession.sessionPreset = .photo
            }

            // Audio input for video recording
            if let audioDevice = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: audioDevice) {
                if captureSession.canAddInput(audioInput) {
                    captureSession.addInput(audioInput)
                }
            }

            // Video input — back wide camera
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                captureSession.commitConfiguration()
                return
            }

            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }

            Task { @MainActor [weak self] in
                self?.currentDevice = device
                self?.currentInput = input
            }

            // Video data output (for frame analysis)
            videoDataOutput.setSampleBufferDelegate(self, queue: analysisQueue)
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            if captureSession.canAddOutput(videoDataOutput) {
                captureSession.addOutput(videoDataOutput)
            }

            // Photo output
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
            }

            // Video recorder output
            if captureSession.canAddOutput(movieOutput) {
                captureSession.addOutput(movieOutput)
            }

            captureSession.commitConfiguration()
            captureSession.startRunning()
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

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        Task { @MainActor [weak self] in
            guard let self else { return }

            // Only analyze in photo mode
            guard self.currentMode == .photo else { return }

            let alignmentMode = self.isAlignmentModeOn
            let lastTime = self.lastAnalysisTime

            if alignmentMode {
                guard now - lastTime >= self.alignmentThrottleInterval else { return }
                self.lastAnalysisTime = now
                self.runAlignmentAnalysis(ciImage: ciImage)
            } else {
                guard now - lastTime >= self.compositionThrottleInterval else { return }
                self.lastAnalysisTime = now
                self.isAnalyzing = true
                self.runCompositionAnalysis(ciImage: ciImage)
                self.runFilterAnalysis(ciImage: ciImage)
            }
        }
    }
}

// MARK: - Analysis Dispatchers

extension CameraViewModel {

    private func runCompositionAnalysis(ciImage: CIImage) {
        let queue = analysisQueue
        queue.async { [weak self] in
            CompositionAnalyzer.analyze(ciImage: ciImage) { result in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.suggestedBox = result.saliencyBox
                    self.suggestedZoom = result.suggestedZoom
                    self.isAnalyzing = false
                }
            }
        }
    }

    private func runFilterAnalysis(ciImage: CIImage) {
        let ctx = ciContext
        let queue = analysisQueue
        queue.async { [weak self] in
            let recommendation = SceneFilterRecommender.recommend(for: ciImage, context: ctx)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.sceneDescription = recommendation.sceneDescription
                self.filterName = recommendation.filterName
                self.filterReason = recommendation.reason
                self.isLowLight = recommendation.filterName == "Night Boost"
            }
        }
    }

    private func runAlignmentAnalysis(ciImage: CIImage) {
        analysisQueue.async { [weak self] in
            AlignmentGuide.evaluate(ciImage: ciImage) { guidance in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.targetCompositionPoint = guidance.targetPoint
                    self.currentSubjectPoint = guidance.currentSubjectPoint
                    self.isAligned = guidance.isAligned
                    self.alignmentInstruction = guidance.instruction
                }
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
            guard let self else { return }

            // Check if this is a panorama capture
            if self.currentMode == .panorama {
                self.panoramaManager.captureAtCurrentPosition(imageData: data)
                return
            }

            // Standard photo flow
            // 1. Apply recommended filter
            var finalImage = SceneFilterRecommender.applyLastFilter(to: rawImage)

            // 2. Apply night enhancement if low light
            if self.isLowLight {
                let nightResult = NightEnhancer.enhanceIfNeeded(finalImage)
                if nightResult.isLowLight, let enhanced = nightResult.enhancedImage {
                    finalImage = enhanced
                }
            }

            // 3. Show captured image
            self.capturedImage = finalImage
            self.showCapturedPhoto = true
            self.sessionPhotoCount += 1

            // 4. Save to Photos
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

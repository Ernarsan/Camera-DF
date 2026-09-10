import AVFoundation
import Combine
import CoreImage
import Photos
import SwiftUI
import UIKit

/// Central view model that manages the camera session, frame analysis,
/// photo capture, and publishes all state consumed by the UI layer.
@MainActor
final class CameraViewModel: NSObject, ObservableObject {

    // MARK: - Published State (§5 of TZ)

    @Published var isAnalyzing: Bool = false
    @Published var suggestedBox: CGRect?
    @Published var suggestedZoom: CGFloat?
    @Published var sceneDescription: String = ""
    @Published var filterName: String = ""
    @Published var filterReason: String = ""
    @Published var capturedImage: UIImage?
    @Published var currentZoomFactor: CGFloat = 1.0

    // AlignmentGuide
    @Published var targetCompositionPoint: CGPoint?
    @Published var currentSubjectPoint: CGPoint?
    @Published var isAligned: Bool = false
    @Published var alignmentInstruction: String = ""

    // NightEnhancer
    @Published var isLowLight: Bool = false

    // UI state
    @Published var isAlignmentModeOn: Bool = false
    @Published var isCameraAuthorized: Bool = false
    @Published var showCapturedPhoto: Bool = false

    // MARK: - Session & Outputs

    nonisolated let captureSession = AVCaptureSession()
    nonisolated private let photoOutput = AVCapturePhotoOutput()
    nonisolated private let videoDataOutput = AVCaptureVideoDataOutput()
    nonisolated private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - Queues

    nonisolated private let sessionQueue = DispatchQueue(label: "com.aicompose.camera.session")
    nonisolated private let analysisQueue = DispatchQueue(label: "com.aicompose.camera.analysis", qos: .userInitiated)

    // MARK: - Throttling

    private var lastAnalysisTime: CFAbsoluteTime = 0
    private let compositionThrottleInterval: CFTimeInterval = 0.6
    private let alignmentThrottleInterval: CFTimeInterval = 0.3

    // MARK: - Device

    private var currentDevice: AVCaptureDevice?

    // MARK: - Init

    override init() {
        super.init()
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
        let clamped = min(max(zoom, 1.0), device.activeFormat.videoMaxZoomFactor)
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

    /// Capture a photo, apply the last recommended filter, and save to Photos.
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - Session Configuration

    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            captureSession.beginConfiguration()
            captureSession.sessionPreset = .photo

            // Input — back wide camera
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

        // Read alignment mode flag from MainActor-isolated state
        // We use a task to read it safely.
        Task { @MainActor [weak self] in
            guard let self else { return }
            let alignmentMode = self.isAlignmentModeOn
            let lastTime = self.lastAnalysisTime

            if alignmentMode {
                // Alignment mode — higher frequency (0.3 sec)
                guard now - lastTime >= self.alignmentThrottleInterval else { return }
                self.lastAnalysisTime = now

                self.runAlignmentAnalysis(ciImage: ciImage)
            } else {
                // Standard mode — composition + filter (0.6 sec)
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

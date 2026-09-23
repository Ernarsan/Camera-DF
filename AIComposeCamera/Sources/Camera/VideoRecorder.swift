import AVFoundation
import Photos
import UIKit
import Combine

@MainActor
public final class VideoRecorder: NSObject, ObservableObject {
    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var recordingDuration: TimeInterval = 0
    
    nonisolated public let movieOutput: AVCaptureMovieFileOutput
    
    private var timer: Timer?
    
    public init(movieOutput: AVCaptureMovieFileOutput = AVCaptureMovieFileOutput()) {
        self.movieOutput = movieOutput
        super.init()
    }
    
    public func configureOutput(for session: AVCaptureSession) {
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }
    }
    
    public func startRecording() {
        guard !movieOutput.isRecording else { return }
        
        AudioHapticEngine.shared.playRecordStartSound()
        
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = "video_\(UUID().uuidString).mov"
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        
        movieOutput.startRecording(to: fileURL, recordingDelegate: self)
        
        Task { @MainActor in
            self.isRecording = true
            self.startTimer()
        }
    }
    
    public func stopRecording() {
        guard movieOutput.isRecording else { return }
        AudioHapticEngine.shared.playRecordStopSound()
        movieOutput.stopRecording()
        
        Task { @MainActor in
            self.isRecording = false
            self.stopTimer()
        }
    }
    
    @MainActor
    private func startTimer() {
        recordingDuration = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingDuration += 1
            }
        }
    }
    
    @MainActor
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

extension VideoRecorder: AVCaptureFileOutputRecordingDelegate {
    nonisolated public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        
        let cleanup = {
            do {
                if FileManager.default.fileExists(atPath: outputFileURL.path) {
                    try FileManager.default.removeItem(at: outputFileURL)
                }
            } catch {
                print("Failed to remove temporary video file: \(error.localizedDescription)")
            }
        }
        
        if let error = error {
            print("Video recording failed with error: \(error.localizedDescription)")
            cleanup()
            return
        }
        
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                print("Photo library access not authorized.")
                cleanup()
                return
            }
            
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
            } completionHandler: { success, error in
                if let error = error {
                    print("Failed to save video to Photos: \(error.localizedDescription)")
                } else if success {
                    print("Video successfully saved to Photos.")
                }
                cleanup()
            }
        }
    }
}

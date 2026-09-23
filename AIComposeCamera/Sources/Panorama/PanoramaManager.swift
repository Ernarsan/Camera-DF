import Foundation
import CoreMotion
import Photos
import UIKit
import Combine

struct PanoramaPoint: Identifiable, Sendable {
    let id: Int
    let targetPitch: Double  // radians
    let targetYaw: Double    // radians
    var isCaptured: Bool = false
    var capturedImageData: Data? = nil
}

@MainActor
class PanoramaManager: ObservableObject {
    @Published var capturePoints: [PanoramaPoint] = []
    @Published var currentPitch: Double = 0
    @Published var currentYaw: Double = 0
    @Published var capturedCount: Int = 0
    @Published var totalPoints: Int = 12
    @Published var isCapturing: Bool = false
    @Published var isComplete: Bool = false
    @Published var nearbyPointIndex: Int? = nil

    private let motionManager = CMMotionManager()
    private let motionQueue = OperationQueue()
    
    private var initialPitch: Double?
    private var initialYaw: Double?

    nonisolated let alignmentThreshold: Double = 0.15
    nonisolated let nearbyThreshold: Double = 0.4
    
    init() {
        setupPoints()
    }
    
    private func setupPoints() {
        capturePoints = []
        var id = 0
        
        // Ring of 8 points at pitch=0 (horizontal), yaw spaced every 45°
        for i in 0..<8 {
            // Yaw from -pi to pi
            let yaw = Double(i) * (.pi / 4.0) - .pi
            capturePoints.append(PanoramaPoint(id: id, targetPitch: 0, targetYaw: yaw))
            id += 1
        }
        
        // 2 points looking up (pitch ~45°, yaw 0° and 180°)
        capturePoints.append(PanoramaPoint(id: id, targetPitch: .pi / 4.0, targetYaw: 0))
        id += 1
        capturePoints.append(PanoramaPoint(id: id, targetPitch: .pi / 4.0, targetYaw: .pi))
        id += 1
        
        // 2 points looking down (pitch ~-45°, yaw 0° and 180°)
        capturePoints.append(PanoramaPoint(id: id, targetPitch: -.pi / 4.0, targetYaw: 0))
        id += 1
        capturePoints.append(PanoramaPoint(id: id, targetPitch: -.pi / 4.0, targetYaw: .pi))
        
        totalPoints = capturePoints.count
    }
    
    func startSession() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        isCapturing = true
        initialPitch = nil
        initialYaw = nil
        motionQueue.maxConcurrentOperationCount = 1
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: motionQueue) { @Sendable [weak self] motion, error in
            guard let motion = motion, error == nil else { return }
            
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if self.initialPitch == nil {
                    self.initialPitch = motion.attitude.pitch
                    self.initialYaw = motion.attitude.yaw
                }
                
                if let initPitch = self.initialPitch, let initYaw = self.initialYaw {
                    let relPitch = motion.attitude.pitch - initPitch
                    var relYaw = motion.attitude.yaw - initYaw
                    
                    // Normalize yaw to -pi ... pi
                    while relYaw > .pi { relYaw -= 2 * .pi }
                    while relYaw < -.pi { relYaw += 2 * .pi }
                    
                    self.updatePosition(pitch: relPitch, yaw: relYaw)
                }
            }
        }
    }
    
    func stopSession() {
        motionManager.stopDeviceMotionUpdates()
        isCapturing = false
    }
    
    private func updatePosition(pitch: Double, yaw: Double) {
        currentPitch = pitch
        currentYaw = yaw
        
        // Find nearby point
        var closestIdx: Int? = nil
        var minDistance: Double = .greatestFiniteMagnitude
        
        for (index, point) in capturePoints.enumerated() {
            if point.isCaptured { continue }
            
            let pitchDiff = abs(point.targetPitch - pitch)
            var yawDiff = abs(point.targetYaw - yaw)
            
            // Normalize yaw diff to -pi ... pi
            if yawDiff > .pi {
                yawDiff = 2 * .pi - yawDiff
            }
            
            let distance = sqrt(pitchDiff * pitchDiff + yawDiff * yawDiff)
            if distance < minDistance {
                minDistance = distance
                closestIdx = index
            }
        }
        
        if minDistance <= nearbyThreshold {
            nearbyPointIndex = closestIdx
        } else {
            nearbyPointIndex = nil
        }
    }
    
    func captureAtCurrentPosition(imageData: Data) {
        // Find closest point within alignment threshold
        var closestIdx: Int? = nil
        var minDistance: Double = .greatestFiniteMagnitude
        
        for (index, point) in capturePoints.enumerated() {
            if point.isCaptured { continue }
            
            let pitchDiff = abs(point.targetPitch - currentPitch)
            var yawDiff = abs(point.targetYaw - currentYaw)
            if yawDiff > .pi { yawDiff = 2 * .pi - yawDiff }
            
            let distance = sqrt(pitchDiff * pitchDiff + yawDiff * yawDiff)
            if distance < minDistance {
                minDistance = distance
                closestIdx = index
            }
        }
        
        if let idx = closestIdx {
            capturePoints[idx].isCaptured = true
            capturePoints[idx].capturedImageData = imageData
            capturedCount += 1
            
            if capturedCount >= totalPoints {
                isComplete = true
                stopSession()
            }
        }
    }
    
    func reset() {
        stopSession()
        setupPoints()
        currentPitch = 0
        currentYaw = 0
        capturedCount = 0
        isComplete = false
        nearbyPointIndex = nil
    }
    
    func saveAllToLibrary() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { @Sendable status in
            guard status == .authorized || status == .limited else { return }
            
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                for point in self.capturePoints {
                    if let data = point.capturedImageData, let image = UIImage(data: data) {
                        PHPhotoLibrary.shared().performChanges({
                            PHAssetChangeRequest.creationRequestForAsset(from: image)
                        }) { success, error in
                            if let error = error {
                                print("Error saving panorama part: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        }
    }
}

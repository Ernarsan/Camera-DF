import UIKit
import AVFoundation

public class AudioHapticEngine {
    public static let shared = AudioHapticEngine()
    
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()
    
    private var isMuted: Bool = false
    
    private init() {
        impactLight.prepare()
        impactMedium.prepare()
        impactRigid.prepare()
        selection.prepare()
        notification.prepare()
    }
    
    // MARK: - Haptics
    
    public func playHapticZoom() {
        selection.selectionChanged()
    }
    
    public func playHapticAlignment(isAligned: Bool) {
        if isAligned {
            impactRigid.impactOccurred()
        } else {
            impactLight.impactOccurred(intensity: 0.5)
        }
    }
    
    public func playHapticShutter() {
        impactMedium.impactOccurred()
    }
    
    public func playHapticSuccess() {
        notification.notificationOccurred(.success)
    }
    
    public func playHapticWarning() {
        notification.notificationOccurred(.warning)
    }
    
    // MARK: - Audio Systems
    
    public func playShutterSound() {
        if !isMuted {
            AudioServicesPlaySystemSound(1108) // camera shutter
        }
    }
    
    public func playRecordStartSound() {
        if !isMuted {
            AudioServicesPlaySystemSound(1117) // video record start
        }
    }
    
    public func playRecordStopSound() {
        if !isMuted {
            AudioServicesPlaySystemSound(1118) // video record stop
        }
    }
}

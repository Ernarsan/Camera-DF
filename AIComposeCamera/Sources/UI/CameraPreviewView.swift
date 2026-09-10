import SwiftUI
import AVFoundation

/// UIViewRepresentable that wraps an AVCaptureVideoPreviewLayer
/// for displaying the live camera feed in SwiftUI.
struct CameraPreviewView: UIViewRepresentable {

    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        // Session is managed externally; nothing to update here.
    }

    // MARK: - Inner UIView subclass

    /// A plain UIView whose `layerClass` is `AVCaptureVideoPreviewLayer`,
    /// so the preview automatically resizes with Auto Layout.
    final class PreviewUIView: UIView {

        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            // swiftlint:disable:next force_cast
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

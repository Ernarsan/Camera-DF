import SwiftUI

/// Draws an animated rectangle around the most salient object detected by Vision.
///
/// Vision returns bounding boxes in normalized coordinates with origin at bottom-left.
/// This view converts them to SwiftUI's top-left origin coordinate space.
struct SaliencyBoxView: View {

    /// Normalized bounding box from Vision (origin bottom-left, 0…1).
    let box: CGRect

    /// Size of the parent container (camera preview) in points.
    let containerSize: CGSize

    @State private var isVisible = false

    var body: some View {
        let converted = convertToSwiftUI(box, in: containerSize)

        RoundedRectangle(cornerRadius: 6)
            .stroke(Color.yellow, lineWidth: 2.5)
            .frame(width: converted.width, height: converted.height)
            .position(x: converted.midX, y: converted.midY)
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.85)
            .animation(.easeOut(duration: 0.3), value: isVisible)
            .onAppear { isVisible = true }
            .onChange(of: box.origin.x) { _ in
                // Re-animate when box changes significantly
                isVisible = false
                withAnimation(.easeOut(duration: 0.3).delay(0.05)) {
                    isVisible = true
                }
            }
    }

    // MARK: - Coordinate Conversion

    /// Convert Vision normalized coordinates (bottom-left origin) to SwiftUI points (top-left origin).
    private func convertToSwiftUI(_ visionRect: CGRect, in size: CGSize) -> CGRect {
        let x = visionRect.origin.x * size.width
        let y = (1 - visionRect.origin.y - visionRect.height) * size.height
        let width = visionRect.width * size.width
        let height = visionRect.height * size.height
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

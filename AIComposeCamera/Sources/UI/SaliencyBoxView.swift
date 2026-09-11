import SwiftUI

/// Draws animated corner brackets around the most salient object detected by Vision.
///
/// Vision returns bounding boxes in normalized coordinates with origin at bottom-left.
/// This view converts them to SwiftUI's top-left origin coordinate space.
struct SaliencyBoxView: View {

    /// Normalized bounding box from Vision (origin bottom-left, 0…1).
    let box: CGRect

    /// Size of the parent container (camera preview) in points.
    let containerSize: CGSize

    @State private var isVisible = false

    private let cornerLength: CGFloat = 20
    private let cornerLineWidth: CGFloat = 2.5

    var body: some View {
        let converted = convertToSwiftUI(box, in: containerSize)

        ZStack {
            // Corner brackets instead of full rectangle
            // Top Left
            cornerBracket(rotation: 0)
                .position(
                    x: converted.minX + cornerLength / 2,
                    y: converted.minY + cornerLength / 2
                )

            // Top Right
            cornerBracket(rotation: 90)
                .position(
                    x: converted.maxX - cornerLength / 2,
                    y: converted.minY + cornerLength / 2
                )

            // Bottom Left
            cornerBracket(rotation: 270)
                .position(
                    x: converted.minX + cornerLength / 2,
                    y: converted.maxY - cornerLength / 2
                )

            // Bottom Right
            cornerBracket(rotation: 180)
                .position(
                    x: converted.maxX - cornerLength / 2,
                    y: converted.maxY - cornerLength / 2
                )
        }
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.85)
        .animation(.easeOut(duration: 0.3), value: isVisible)
        .onAppear { isVisible = true }
        .onChange(of: box.origin.x) { _ in
            isVisible = false
            withAnimation(.easeOut(duration: 0.3).delay(0.05)) {
                isVisible = true
            }
        }
    }

    // MARK: - Corner Bracket Shape

    @ViewBuilder
    private func cornerBracket(rotation: Double) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: cornerLength))
            path.addLine(to: CGPoint(x: 0, y: 2))
            path.addQuadCurve(
                to: CGPoint(x: 2, y: 0),
                control: CGPoint(x: 0, y: 0)
            )
            path.addLine(to: CGPoint(x: cornerLength, y: 0))
        }
        .stroke(Color.yellow, lineWidth: cornerLineWidth)
        .frame(width: cornerLength, height: cornerLength)
        .rotationEffect(.degrees(rotation))
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

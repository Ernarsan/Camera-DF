import UIKit
import CoreGraphics

/// Generates and renders the iconic Y2K glowing digital date stamp directly onto photos.
public enum RetroDateStamper {

    public enum DateStyle: String, CaseIterable, Identifiable {
        case currentYear = "Current ('26)"
        case retro2004 = "Y2K ('04)"
        case retro1998 = "Retro ('98)"

        public var id: String { rawValue }
    }

    /// Format string for the date stamp (e.g. "'26 09 23")
    public static func formattedDate(style: DateStyle = .currentYear, date: Date = Date()) -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)

        let yearString: String
        switch style {
        case .currentYear:
            let fullYear = calendar.component(.year, from: date)
            yearString = String(format: "'%02d", fullYear % 100)
        case .retro2004:
            yearString = "'04"
        case .retro1998:
            yearString = "'98"
        }

        return String(format: "%@ %02d %02d", yearString, month, day)
    }

    /// Renders the glowing date stamp onto the given image in its bottom-right corner.
    public static func stamp(
        image: UIImage,
        profile: RetroCameraProfile,
        style: DateStyle = .currentYear
    ) -> UIImage {
        let dateText = formattedDate(style: style)
        let color = profile.dateStampColor

        let imageSize = image.size
        let renderer = UIGraphicsImageRenderer(size: imageSize)

        return renderer.image { context in
            // Draw original image
            image.draw(in: CGRect(origin: .zero, size: imageSize))

            let cgContext = context.cgContext

            // Calculate font size relative to image dimensions (roughly 2.6% of image height)
            let fontSize = max(18.0, imageSize.height * 0.026)
            let paddingX = imageSize.width * 0.04
            let paddingY = imageSize.height * 0.04

            // Authentic digital monospace font
            let font: UIFont
            if let digitalFont = UIFont(name: "Menlo-BoldItalic", size: fontSize) {
                font = digitalFont
            } else {
                font = UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .black)
            }

            // Outer glow shadow
            cgContext.saveGState()
            cgContext.setShadow(
                offset: CGSize(width: 0, height: 1),
                blur: fontSize * 0.45,
                color: color.withAlphaComponent(1.0).cgColor
            )

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color,
                .kern: fontSize * 0.08
            ]

            let attributedString = NSAttributedString(string: dateText, attributes: attributes)
            let textSize = attributedString.size()

            let textRect = CGRect(
                x: imageSize.width - textSize.width - paddingX,
                y: imageSize.height - textSize.height - paddingY,
                width: textSize.width,
                height: textSize.height
            )

            attributedString.draw(in: textRect)
            cgContext.restoreGState()

            // Draw once more on top for crispness
            attributedString.draw(in: textRect)
        }
    }
}

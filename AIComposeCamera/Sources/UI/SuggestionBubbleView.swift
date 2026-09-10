import SwiftUI

/// A semi-transparent bubble that displays AI suggestion text.
///
/// Used for:
/// - "AI is analyzing / Please hold still"
/// - Filter recommendation with reason
/// - AlignmentGuide instructions
struct SuggestionBubbleView: View {

    let text: String
    let subtitle: String?
    let icon: String

    init(text: String, subtitle: String? = nil, icon: String = "sparkles") {
        self.text = text
        self.subtitle = subtitle
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .opacity
        ))
    }
}

// MARK: - Convenience Factory Methods

extension SuggestionBubbleView {

    /// Bubble shown while AI is analyzing the scene.
    static var analyzing: SuggestionBubbleView {
        SuggestionBubbleView(
            text: "AI is analyzing",
            subtitle: "Please hold still",
            icon: "brain"
        )
    }

    /// Bubble for filter recommendation.
    static func filterRecommendation(name: String, reason: String) -> SuggestionBubbleView {
        SuggestionBubbleView(
            text: name,
            subtitle: reason,
            icon: "camera.filters"
        )
    }

    /// Bubble for alignment guide instructions.
    static func alignment(instruction: String) -> SuggestionBubbleView {
        SuggestionBubbleView(
            text: instruction,
            icon: "viewfinder"
        )
    }
}

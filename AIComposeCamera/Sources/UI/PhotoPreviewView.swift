import SwiftUI

struct PhotoPreviewView: View {
    let image: UIImage
    let filterName: String
    
    let onDismiss: () -> Void
    let onSave: () -> Void
    let onShare: () -> Void
    let onExportExternal: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .ignoresSafeArea()
            
            VStack {
                // Top Bar
                HStack(alignment: .top) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    if !filterName.isEmpty {
                        Text(filterName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                Spacer()
                
                // Bottom Actions
                HStack(spacing: 16) {
                    actionButton(
                        icon: "arrow.uturn.left",
                        title: "Retake",
                        color: .white,
                        action: onDismiss
                    )
                    
                    actionButton(
                        icon: "square.and.arrow.down",
                        title: "Save",
                        color: .green,
                        action: onSave
                    )
                    
                    actionButton(
                        icon: "square.and.arrow.up",
                        title: "Share",
                        color: .white,
                        action: onShare
                    )
                    
                    actionButton(
                        icon: "externaldrive",
                        title: "Export",
                        color: .blue,
                        action: onExportExternal
                    )
                }
                .padding(.horizontal)
                .padding(.vertical, 24)
                .background(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea(edges: .bottom)
                )
            }
        }
        .transition(.opacity)
        .animation(.easeInOut, value: true)
    }
    
    @ViewBuilder
    private func actionButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
                
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

import SwiftUI

struct UpdateBadgeView: View {
    @ObservedObject var updateManager = UpdateManager.shared
    @ObservedObject var configManager = ConfigManager.shared
    
    @State private var isAnimating = false
    
    var body: some View {
        if case .available(let version) = updateManager.state {
            Button(action: {
                print("[UpdateBadgeView] User clicked update badge: \(version)")
                updateManager.showModal = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                    
                    Text("\(version) available")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(accentColor.opacity(0.15))
                )
                .overlay(
                    Capsule()
                        .stroke(accentColor.opacity(0.4), lineWidth: 0.5)
                )
                .foregroundColor(accentColor)
                .scaleEffect(isAnimating ? 1.05 : 1.0)
            }
            .buttonStyle(.plain)
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .opacity
            ))
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
        }
    }
    
    private var accentColor: Color {
        let theme = configManager.config.colors.resolveTheme()
        // Index 2 is usually green/success in our themes (palette: [bg, fg, green, yellow, red, ...])
        return Color(hex: theme.palette[2])
    }
}

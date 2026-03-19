import SwiftUI

struct UpdateLetterView: View {
    @ObservedObject var configManager = ConfigManager.shared
    let version: String
    let changelog: String
    let onContinue: () -> Void
    
    var body: some View {
        ZStack {
            // Background Dimmer
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundColor(accentColor)
                    
                    Text("Aether has been updated")
                        .font(.system(size: 28, weight: .bold))
                    
                    Text("You're now running version \(version)")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                // Changelog Card
                VStack(alignment: .leading, spacing: 16) {
                    Text("WHAT'S NEW")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    ScrollView {
                        Text(changelog)
                            .font(.system(size: 14, design: .monospaced))
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 240)
                }
                .padding(24)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
                
                // Footer
                Button(action: onContinue) {
                    HStack {
                        Text("Continue to Aether")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(accentColor)
                    .foregroundColor(.black)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 500)
            .padding(40)
        }
    }
    
    private var accentColor: Color {
        let theme = configManager.config.colors.resolveTheme()
        return Color(hex: theme.palette[2])
    }
}

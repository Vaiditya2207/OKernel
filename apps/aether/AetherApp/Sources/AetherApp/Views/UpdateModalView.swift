import SwiftUI

struct UpdateModalView: View {
    @ObservedObject var updateManager = UpdateManager.shared
    @ObservedObject var configManager = ConfigManager.shared
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            // Background Dimmer
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    if !updateManager.state.isProgressState {
                        isPresented = false
                    }
                }
            
            // Modal Container
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("SOFTWARE UPDATE")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if !updateManager.state.isProgressState {
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)
                
                Divider().opacity(0.1)
                
                // Content Based on State
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        contentView
                    }
                    .padding(20)
                }
                .frame(maxHeight: 400)
                
                Divider().opacity(0.1)
                
                // Footer / Actions
                HStack(spacing: 12) {
                    footerActions
                }
                .padding(20)
            }
            .frame(width: 480)
            .background(
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    @ViewBuilder
    private var contentView: some View {
        if let info = updateManager.availableVersion {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Aether \(info.version)")
                        .font(.system(size: 24, weight: .bold))
                    
                    Spacer()
                    
                    Text(info.releaseDate.prefix(10)) // Simple date extract
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Text(info.description)
                    .font(.system(size: 14))
                    .foregroundColor(.primary.opacity(0.8))
                
                if !info.changelog.isEmpty {
                    Text("WHAT'S NEW")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    
                    Text(info.changelog)
                        .font(.system(size: 13, design: .monospaced))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(6)
                }
            }
        } else if case .failed(let error) = updateManager.state {
             VStack(alignment: .center, spacing: 12) {
                 Image(systemName: "exclamationmark.triangle.fill")
                     .font(.system(size: 40))
                     .foregroundColor(.red)
                 
                 Text("Update Failed")
                     .font(.headline)
                 
                 Text(error)
                     .font(.subheadline)
                     .multilineTextAlignment(.center)
                     .foregroundColor(.secondary)
             }
             .frame(maxWidth: .infinity)
        } else {
            // General status for checking/idle?
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding()
        }
    }
    
    @ViewBuilder
    private var footerActions: some View {
        switch updateManager.state {
        case .available:
            Button("Skip This Version") {
                // Future: Add to ignored versions
                isPresented = false
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Download and Install") {
                updateManager.downloadUpdate()
            }
            .buttonStyle(ProminentButtonStyle())
            
        case .downloading:
            VStack(spacing: 8) {
                ProgressView(value: updateManager.downloadProgress)
                    .progressViewStyle(.linear)
                
                HStack {
                    Text("\(Int(updateManager.downloadProgress * 100))%")
                        .font(.system(size: 10, design: .monospaced))
                    Spacer()
                    Button("Cancel") {
                        updateManager.cancelDownload()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                }
            }
            .frame(maxWidth: .infinity)
            
        case .readyToInstall:
            Button("Install Later") {
                isPresented = false
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button("Restart & Update") {
                updateManager.applyUpdate()
            }
            .buttonStyle(ProminentButtonStyle())
            
        case .installing:
             HStack(spacing: 12) {
                 ProgressView()
                     .scaleEffect(0.8)
                 Text(updateManager.statusMessage.isEmpty ? "Installing..." : updateManager.statusMessage)
                     .font(.system(size: 13, design: .monospaced))
             }
             .frame(maxWidth: .infinity)
             
        case .restartRequired:
            Spacer()
            Button("Restart Now") {
                updateManager.restartApp()
            }
            .buttonStyle(ProminentButtonStyle())
            
        case .failed:
            Spacer()
            Button("Try Again") {
                updateManager.checkForUpdates()
            }
            .buttonStyle(ProminentButtonStyle())
            
        default:
            EmptyView()
        }
    }
    
    private var accentColor: Color {
        let theme = configManager.config.colors.resolveTheme()
        return Color(hex: theme.palette[2])
    }
}

struct ProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(6)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}


import SwiftUI
import Combine

@main
struct AetherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var tabManager = TabManager()
    @StateObject var updateManager = UpdateManager.shared
    @ObservedObject var configManager = ConfigManager.shared
    
    // First Run Experience
    @AppStorage("hasSeenStartup") private var hasSeenStartup = false
    @State private var showStartup = false
    
    @State private var showRestoreToast = false
    @State private var restoreTimer: Timer? = nil
    @State private var interactionCancellable: AnyCancellable?
    
    @Environment(\.scenePhase) var scenePhase

    // Leader Key State
    @State private var isWindowMode = false
    
    var body: some Scene {
        WindowGroup("Aether") {
            ZStack(alignment: .top) {
                // Main Window Background & Content
                // Hide strictly during startup to allow "floating logo" effect
                Group {
                    BackgroundView(material: configManager.config.window.blurType.material)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // Custom Centered Title Bar
                        ZStack {
                            DraggableTitleBarView()
                                .frame(height: 28)
                            
                            if let session = tabManager.activeSession {
                                Text(session.windowTitle)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                        .id(session.id.uuidString + session.windowTitle) // Redraw on session/title change
                            }
                            
                            // Title Bar Buttons
                            HStack {
                                Spacer()
                                
                                UpdateBadgeView()
                                    .padding(.trailing, 10)
                            }
                            .frame(height: 28)
                        }
                        .frame(height: 28)
                            
                            TabBarView(
                                tabManager: tabManager,
                                onNewTab: { tabManager.addTab() },
                                onCloseTab: { id in tabManager.closeTab(id: id) }
                            )
                            .frame(height: 28)
                            .background(Color.clear)
                        
                        if let tab = tabManager.activeTab {
                            TabContentView(
                                tab: tab,
                                tabManager: tabManager,
                                configManager: configManager,
                                onHandleAction: { action, session in
                                    return handleAction(action, in: session)
                                }
                            )
                            .id(tab.id) // Identify by tab ID so switching tabs refreshes view tree
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            // Fallback?
                            Color.black
                        }
                    }
                    .layoutPriority(1)
                    .ignoresSafeArea()
                    
                    // Window Mode Indicator
                    if isWindowMode {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("WINDOW MODE")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(6)
                                    .background(Color.yellow) // User said blue border is bad, so maybe yellow warning color?
                                    .foregroundColor(.black)
                                    .cornerRadius(4)
                                    .padding()
                            }
                        }
                    }

                    // ScrollBar - Attach to active session
                    if configManager.config.ui.scrollbar.visible, let session = tabManager.activeSession {
                        HStack {
                            Spacer()
                            CustomScrollBar(scrollState: session.scrollState) { t in
                                session.scrollState.userScrollRequest.send(t)
                            }
                            .frame(width: configManager.config.ui.scrollbar.width)
                            .padding(.top, 28 + configManager.config.ui.scrollbar.padding.top) // Offset for tab bar
                            .padding(.bottom, configManager.config.ui.scrollbar.padding.bottom)
                            .layoutPriority(0)
                            .background(Color.black.opacity(0.1))
                        }
                    }
                }
                .opacity(showStartup ? 0 : 1) // Hide main content during startup
                .animation(.easeIn(duration: 0.5), value: showStartup)
                
                // Startup Screen Overlay
                if showStartup {
                    StartupView(isPresented: $showStartup)
                        .zIndex(100)
                        .transition(.opacity)
                }
                
                // Session Restore Toast
                if showRestoreToast {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            RestoreToastView(shortcut: configManager.config.session.restoreShortcut)
                                .onTapGesture {
                                    handleRestore()
                                }
                        }
                    }
                    .padding()
                    .zIndex(101)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .background(Color.clear) // Ensure window background doesn't bleed if possible
            .onAppear {
                // Register TabManager for saving
                SessionManager.shared.tabManager = tabManager
                
                if !hasSeenStartup {
                    showStartup = true
                }
                
                // Trigger async session loading — does NOT block main thread
                SessionManager.shared.loadAsync()
                
                // Update management
                updateManager.schedulePeriodicCheck()
            }
            .onReceive(SessionManager.shared.$isLoaded) { loaded in
                guard loaded else { return }
                
                // Sessions are now loaded — handle restore logic
                let strategy = configManager.config.session.restoreStrategy
                let hasSavedSession = SessionManager.shared.restoreLastSession() != nil
                
                if hasSavedSession {
                    switch strategy {
                    case .always:
                        print("[AetherApp] Auto-restoring session (Always).")
                        if let saved = SessionManager.shared.restoreLastSession() {
                            tabManager.restore(from: saved)
                        }
                    case .ask:
                        if configManager.config.ui.showTooltips {
                            print("[AetherApp] Showing restore toast.")
                            showRestoreToast = true
                            // Auto-hide after 7 seconds
                            restoreTimer?.invalidate()
                            restoreTimer = Timer.scheduledTimer(withTimeInterval: 7.0, repeats: false) { _ in
                                withAnimation(.easeOut(duration: 2.0)) {
                                    showRestoreToast = false
                                }
                            }
                            setupInteractionListener()
                        }
                    case .never:
                        print("[AetherApp] Starting fresh session (Never).")
                    }
                } else {
                     print("[AetherApp] No saved session to restore.")
                }
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .background || newPhase == .inactive {
                    print("[AetherApp] Saving session...")
                    // Save current session state
                    SessionManager.shared.saveSession(tabs: tabManager.tabs, activeTabId: tabManager.activeTabId)
                }
            }
            .onChange(of: tabManager.activeTabId) { _ in
                // Re-setup listener if active session changed while toast is visible
                if showRestoreToast {
                    setupInteractionListener()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in
                print("[AetherApp] Window closing, saving session...")
                SessionManager.shared.saveSession(tabs: tabManager.tabs, activeTabId: tabManager.activeTabId)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in
                tabManager.isFullScreen = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
                tabManager.isFullScreen = false
            }
            .frame(minWidth: 800, minHeight: 600)
        }
        .windowResizability(.contentSize)
        .commands {
            // ... (keep existing commands)
            CommandGroup(replacing: .newItem) {
                Button("New Tab") { tabManager.addTab() }
                    .keyboardShortcut("t", modifiers: .command)
                Button("Close Tab") {
                    if let id = tabManager.activeTabId {
                        tabManager.closeTab(id: id)
                    }
                }
                .keyboardShortcut("w", modifiers: .command)
                
                Divider()
                
                Button("Toggle Full Screen") {
                    NSApp.sendAction(#selector(NSWindow.toggleFullScreen(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .control])
                
                Divider()
                
                // Split Commands
                Button("Split Horizontally") {
                    print("Menu Command: Split Horizontally Triggered")
                    tabManager.splitPane(axis: .horizontal)
                }
                .keyboardShortcut("d", modifiers: .command)
                
                Button("Split Vertically") {
                    print("Menu Command: Split Vertically Triggered")
                    tabManager.splitPane(axis: .vertical)
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                
                Button("Close Pane") {
                    tabManager.closeActivePane()
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])
            }
            // Themes menu...
            CommandMenu("Themes") {
                Button("Transparent (Default)") {
                    NotificationCenter.default.post(name: NSNotification.Name("AetherThemeChanged"), object: "Default")
                }
                Button("Solarized Dark") {
                     NotificationCenter.default.post(name: NSNotification.Name("AetherThemeChanged"), object: "Solarized Dark")
                }
                Button("Dracula") {
                     NotificationCenter.default.post(name: NSNotification.Name("AetherThemeChanged"), object: "Dracula")
                }
                Button("OneDark") {
                     NotificationCenter.default.post(name: NSNotification.Name("AetherThemeChanged"), object: "OneDark")
                }
            }
        }
    }
    
    func setupInteractionListener() {
        interactionCancellable?.cancel()
        if let session = tabManager.activeSession {
            interactionCancellable = session.userInteractionOccurred
                .receive(on: RunLoop.main)
                .sink {
                    if self.showRestoreToast {
                        print("[AetherApp] Interaction detected. Disabling session restore.")
                        withAnimation(.easeOut(duration: 0.5)) {
                            self.showRestoreToast = false
                        }
                        self.restoreTimer?.invalidate()
                        self.interactionCancellable?.cancel()
                    }
                }
        }
    }
    
    func handleRestore() {
        if let saved = SessionManager.shared.restoreLastSession() {
            print("[AetherApp] User restored session via toast/shortcut.")
            tabManager.restore(from: saved)
            withAnimation {
                showRestoreToast = false
            }
            restoreTimer?.invalidate()
            interactionCancellable?.cancel()
        }
    }
    
    // Returns true if action was handled, false if it should fall through (e.g. to terminal input)
    func handleAction(_ action: String, in session: TerminalSession) -> Bool {
        if action == "restore_session" {
            if showRestoreToast {
                handleRestore()
                return true
            }
            return false
        }
        
        if isWindowMode {
            // In window mode, we hijack navigation keys
            switch action {
            case "focus_left": tabManager.moveFocus(direction: .left)
            case "focus_right": tabManager.moveFocus(direction: .right)
            case "focus_up": tabManager.moveFocus(direction: .up)
            case "focus_down": tabManager.moveFocus(direction: .down) 
            default: return false // Let other actions fall through if needed, or consume?
            }
            isWindowMode = false
            return true
        }
        
        switch action {
        case "toggle_fullscreen":
            NSApp.sendAction(#selector(NSWindow.toggleFullScreen(_:)), to: nil, from: nil)
            return true
        case "enter_window_mode":
            isWindowMode = true
            return true
        case "split_horizontal":
            tabManager.splitPane(axis: .horizontal)
            return true
        case "split_vertical":
            tabManager.splitPane(axis: .vertical)
            return true
        case "close_pane":
            tabManager.closeActivePane()
            return true
        case "new_tab":
            tabManager.addTab()
            return true
        case "close_tab":
            // Find tab containing session
            if let tab = tabManager.tabs.first(where: { 
                // Simple check if root is pane, real check would be recursive search
                // But generally session.id is enough info if we track it.
                // For now, assume close_tab means close active tab
                $0.id == tabManager.activeTabId 
            }) {
                tabManager.closeTab(id: tab.id)
            }
            return true
        case "new_window":
            return true // Consumed but nothing happens
        default:
            // For navigation keys (focus_left, etc) when NOT in window mode:
            // Return FALSE so TerminalView sends the key event to the shell.
            return false
        }
    }
}

struct RestoreToastView: View {
    let shortcut: String
    @ObservedObject var config = ConfigManager.shared
    
    var body: some View {
        let theme = config.config.colors.resolveTheme()
        let accentColor = Color(hex: theme.palette[2]) // index 2 is usually green/success in our themes
        let bgColor = Color(hex: theme.background).opacity(0.8)
        let fgColor = Color(hex: theme.foreground)

        HStack(spacing: 8) {
            Text("RESTORE SESSION?")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(fgColor)
            
            Text(shortcut.uppercased())
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(fgColor.opacity(0.1))
                .cornerRadius(3)
                .foregroundColor(accentColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(bgColor)
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(accentColor.opacity(0.3), lineWidth: 0.5)
        )
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Just an empty container for the visual effect, maybe a separator line
struct HeaderView: View {
    var body: some View {
        VStack {
            Spacer()
            Divider()
                .opacity(0.1)
        }
    }
}

struct BackgroundView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}

struct TabContentView: View {
    @ObservedObject var tab: Tab
    @ObservedObject var tabManager: TabManager
    @ObservedObject var configManager: ConfigManager
    
    // Closure to handle actions, passed from parent
    let onHandleAction: (String, TerminalSession) -> Bool
    
    var body: some View {
        PaneView(
            node: tab.root,
            tabManager: tabManager,
            config: configManager.config,
            onAction: onHandleAction
        )
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct DraggableTitleBarView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = DraggableNSView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

class DraggableNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
    
    override func mouseDown(with event: NSEvent) {
        // Double click to toggle fullscreen or zoom?
        if event.clickCount == 2 {
            // Find window and zoom/toggle
            self.window?.zoom(nil)
        } else {
            super.mouseDown(with: event)
        }
    }
}

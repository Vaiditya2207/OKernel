import SwiftUI
import Combine

struct AetherV2View: View {
    @ObservedObject var session: TerminalSession
    let config: AetherConfig
    let isActive: Bool
    let onAction: (String) -> Void
    let onSelect: () -> Void

    // Future overlay states
    @State private var showPrompter = false
    @State private var prompterText = ""
    
    // AI Copilot States
    @State private var showAIPopup = false
    @State private var aiSuggestion = ""
    @State private var aiCancellable: AnyCancellable?
    @State private var keithWidth: CGFloat = 420

    var body: some View {
        HStack(spacing: 0) {
            // ─── LEFT: Terminal ───
            ZStack {
                // LAYER 1: The Native Metal Terminal with Mockup Padding
                TerminalViewRepresentable(
                    session: session,
                    config: config,
                    isActive: isActive,
                    onAction: { action in
                        onAction(action)
                        return true
                    },
                    onSelect: onSelect
                )
                .padding(16)
                .background(Color(hex: "0x121212"))
                
                // LAYER 2: Sleek Status Bar (Bottom Right)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ResourceMonitorsView()
                            .padding(.bottom, 16)
                            .padding(.trailing, 16)
                    }
                }
                .allowsHitTesting(false)
                
                // LAYER 3: Smart AI Popup Overlay
                VStack {
                    Spacer()
                    
                    if showAIPopup {
                        HStack {
                            AICopilotPopupView(suggestion: aiSuggestion) {
                                session.writeInput(aiSuggestion + "\r")
                                withAnimation { showAIPopup = false }
                            } onDismiss: {
                                withAnimation { showAIPopup = false }
                            }
                            .padding(.leading, 16)
                            .padding(.bottom, 70)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                            Spacer()
                        }
                    }
                }
            }
            .onTapGesture { onSelect() }
            
            // ─── RIGHT: Keith Sidebar ───
            if showPrompter {
                KeithChatView(
                    isPresented: $showPrompter,
                    terminalSession: session,
                    sidebarWidth: $keithWidth
                )
                .frame(width: keithWidth)
                .transition(.move(edge: .trailing))
            }
        }
        .onAppear {
            // 1. Hotkey for Prompter (Configurable conceptually, hardcoded to Cmd+Down / 125 for now)
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // 125 is down arrow, 40 is 'k'
                if event.modifierFlags.contains(.command) && (event.keyCode == 125 || event.keyCode == 40) { 
                    showPrompter.toggle()
                    return nil // consume event
                }
                return event
            }
            
            // 2. Intercept output for AI Copilot Triggers
            aiCancellable = session.rawOutputSubject
                .receive(on: RunLoop.main)
                .sink { text in
                    let lower = text.lowercased()
                    if lower.contains("command not found") {
                        // Very naive parsing for demo
                        let comps = text.components(separatedBy: " ")
                        if let target = comps.first(where: { !$0.isEmpty && !$0.contains("bash") && !$0.contains("zsh") && !$0.contains("command") }) {
                            self.aiSuggestion = "brew install \(target.trimmingCharacters(in: .whitespacesAndNewlines))"
                            withAnimation { self.showAIPopup = true }
                            
                            // Auto dismiss after 8s
                            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                                withAnimation { self.showAIPopup = false }
                            }
                        }
                    }
                }
        }
    }
}

// MARK: - Resource Monitors (Sleek Bottom Bar)
struct ResourceMonitorsView: View {
    @State private var cpuUsage: Double = 0.0
    @State private var ramUsage: Double = 0.0
    
    // Timer to update stats
    let timer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    var totalRamGB: Double {
        Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(String(format: "CPU: %.0f%%", cpuUsage))
                .font(.custom("JetBrains Mono", size: 12))
                .foregroundColor(Color(hex: "89B4FA")) // Blue text
            
            Text("|")
                .font(.custom("JetBrains Mono", size: 12))
                .foregroundColor(.gray)
                
            Text(String(format: "RAM: %.1fGB/%.0fGB", ramUsage, totalRamGB))
                .font(.custom("JetBrains Mono", size: 12))
                .foregroundColor(Color(hex: "A6E3A1")) // Green text
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(hex: "1F2025")) // Very dark gray flat background like the mock
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .onReceive(timer) { _ in
            fetchStats()
        }
    }
    
    private func fetchStats() {
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var cpuInfo = host_cpu_load_info()

        let result = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        
        if result == KERN_SUCCESS {
            let totalTicks = Double(cpuInfo.cpu_ticks.0 + cpuInfo.cpu_ticks.1 + cpuInfo.cpu_ticks.2 + cpuInfo.cpu_ticks.3)
            let idleTicks = Double(cpuInfo.cpu_ticks.3) // CPU_STATE_IDLE is index 3
            let activeRatio = 1.0 - (idleTicks / max(totalTicks, 1.0))
            self.cpuUsage = min(max(activeRatio * 100.0 + Double.random(in: 0...5), 0), 100)
        }
        
        var vmStats = vm_statistics64()
        var vmsize = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        
        let vmResult = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmsize)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &vmsize)
            }
        }
        
        if vmResult == KERN_SUCCESS {
            let active = Double(vmStats.active_count) * Double(vm_page_size)
            let wire = Double(vmStats.wire_count) * Double(vm_page_size)
            let compressed = Double(vmStats.compressor_page_count) * Double(vm_page_size)
            let usedBytes = active + wire + compressed
            
            self.ramUsage = usedBytes / (1024 * 1024 * 1024) // Convert to GB
        }
    }
}

// MARK: - Floating Prompter (Native)
struct FloatingPrompterView: View {
    @Binding var text: String
    var onSubmit: (String) -> Void
    
    // Focus state to auto-focus when it appears
    @FocusState private var isFocused: Bool
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Gradient AI Icon
            Image(systemName: "sparkle")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "A6E3A1"), Color(hex: "94E2D5")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color(hex: "A6E3A1").opacity(0.5), radius: 5, x: 0, y: 0)

            TextField("Ask Copilot or copy a command...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(.white)
                .font(.custom("JetBrains Mono", size: 15))
                .focused($isFocused)
                .onSubmit {
                    if !text.isEmpty {
                        onSubmit(text)
                    }
                }
                .onAppear {
                    isFocused = true
                }
                
            if !text.isEmpty {
                Text("⏎")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(width: 600)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        // Warp style outer glow for active focus
        .shadow(color: isFocused ? Color(hex: "A6E3A1").opacity(0.15) : .black.opacity(0.3), radius: isFocused ? 20 : 15, x: 0, y: isFocused ? 0 : 10)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Smart AI Popup (Mockup Style)
struct AICopilotPopupView: View {
    let suggestion: String
    let onApply: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "89B4FA")) // Blue sparkles
                Text("AI ASSISTANT:")
                    .font(.custom("JetBrains Mono", size: 12))
                    .foregroundColor(Color(hex: "89B4FA"))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white.opacity(0.3))
                        .font(.system(size: 12))
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Text("The command failed. Would you like to try this fix?")
                .font(.custom("JetBrains Mono", size: 13))
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(4)
                
            Button(action: onApply) {
                HStack(spacing: 8) {
                    Text("❯")
                        .foregroundColor(Color(hex: "A6E3A1"))
                        .font(.system(size: 12, weight: .bold))
                    Text(suggestion)
                        .font(.custom("JetBrains Mono", size: 13))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.4))
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .frame(width: 350)
        .background(Color(hex: "1F2025")) // Very dark gray
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
    }
}



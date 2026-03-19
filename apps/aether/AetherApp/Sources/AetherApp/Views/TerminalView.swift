import Cocoa
import MetalKit
import CAether

import Combine

class TerminalView: MTKView {
    var renderer: TerminalRenderer?
    
    // Session State
    var terminalSession: TerminalSession
    var onAction: ((String) -> Bool)?
    var onTitleChange: ((String) -> Void)?
    var onSelect: (() -> Void)?
    
    var isActive: Bool = true {
        didSet {
            if oldValue != isActive {
                renderer?.isActive = isActive
                if isActive {
                    self.window?.title = terminalSession.windowTitle
                }
                self.setNeedsDisplay(self.bounds)
            }
        }
    }
    
    // Convenience accessors
    var terminal: OpaquePointer? { terminalSession.terminal }
    var scrollState: TerminalScrollState { terminalSession.scrollState }

    private var hasMouseDragged = false
    
    // Smart Blink State
    private var lastInputTime: TimeInterval = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    // Keyboard Selection State
    private var keyboardSelectionAnchor: (row: UInt32, col: UInt32)?
    private var keyboardSelectionActive: (row: UInt32, col: UInt32)?
    
    // Resize Debounce
    private var resizeWorkItem: DispatchWorkItem?
    // Static queue to serialize resize operations across ALL terminal instances to prevent thread explosion/lock contention
    private static let resizeQueue = DispatchQueue(label: "com.aether.terminal.resize", qos: .userInteractive)

    // Track the last backing scale we used, so we can detect display changes
    private var lastBackingScale: CGFloat = 0
    
    override var intrinsicContentSize: NSSize {
        // Return small size to allow shrinking in SplitView
        return NSSize(width: 1, height: 1)
    }
    
    override func layout() {
        super.layout()
        if let window = self.window {
             let currentScale = window.backingScaleFactor
             self.layer?.contentsScale = currentScale
             let newSize = CGSize(width: self.bounds.width * currentScale,
                                  height: self.bounds.height * currentScale)

             // Detect backing scale change (display connect/disconnect) even if
             // the drawable pixel size happens to stay the same.
             let scaleChanged = (lastBackingScale != 0) && (abs(currentScale - lastBackingScale) > 0.01)
             lastBackingScale = currentScale

             if newSize != self.drawableSize || scaleChanged {
                 // Debounce resize events to prevent crash on extensive resizing
                 self.drawableSize = newSize

                 // Capture view width for scale calculation
                 let currentViewWidth = self.bounds.width

                 resizeWorkItem?.cancel()
                 let item = DispatchWorkItem { [weak self] in
                     guard let self = self else { return }
                  // Run on background thread to avoid blocking Main Thread with Zig resize
                  // SAFEGUARD: Ignore tiny resizes that occur during layout transitions to prevent "Crop" from wiping content.
                  if newSize.width < 100 || newSize.height < 100 {
                      // Skip tiny resize ( < ~10x5 chars)
                      return
                  }

                  self.renderer?.resize(drawableSize: newSize, viewWidth: currentViewWidth)
                  }
                  resizeWorkItem = item

                  // Use serial background queue to prevent thread explosion during rapid resize
                  Self.resizeQueue.asyncAfter(deadline: .now() + 0.05, execute: item) // Reduced debounce to 50ms for better responsiveness
             }
        }
    }
    
    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }
    
    override func mouseDragged(with event: NSEvent) {
        terminalSession.lock.lock()
        defer { terminalSession.lock.unlock() }
        
        guard let terminal = terminal else { return }
        
        // Autoscroll check
        let loc = convert(event.locationInWindow, from: nil)
        if loc.y < 0 {
             // Above view -> Scroll History (Up)
             aether_scroll_view(terminal, -1)
        } else if loc.y > self.bounds.height {
             // Below view -> Scroll Bottom (Down)
             aether_scroll_view(terminal, 1)
        }
        
        // Update Selection
        let (r, c) = pointToGrid(event.locationInWindow)
        aether_selection_drag(terminal, UInt32(r), UInt32(c))
        
        self.setNeedsDisplay(self.bounds)
    }
    
    override func scrollWheel(with event: NSEvent) {
        terminalSession.lock.lock()
        defer { terminalSession.lock.unlock() }
        
        guard let terminal = terminal else { return }
        
        var dy = event.scrollingDeltaY
        
        // Logic to respect "Natural Scrolling" config:
        // System Event magnitude is consistent, but sign depends on system pref.
        // isDirectionInvertedFromDevice is TRUE if "Natural Scrolling" is enabled in OS.
        // We want:
        // If config.natural == true: Behaves like OS Natural.
        // If config.natural == false: Behaves like OS Classic (Unnatural).
        
        let wantNatural = ConfigManager.shared.config.ui.scroll.naturalScrolling
        let isSystemNatural = event.isDirectionInvertedFromDevice
        
        if wantNatural != isSystemNatural {
            dy = -dy
        }
        
        let speed = ConfigManager.shared.config.ui.scroll.speed
        let delta = Int32(dy * Double(speed))
        if delta != 0 {
            // Mouse wheel scrolls view (relative)
            aether_scroll_view(terminal, delta)
            self.setNeedsDisplay(self.bounds)
        }
    }
    
    // Helper for grid coordinates
    private func pointToGrid(_ point: CGPoint) -> (Int, Int) {
        let loc = self.convert(point, from: nil)
        
        // Clamp location to bounds to ensure we get a valid grid cell even if dragging outside
        let clampedX = max(0, min(loc.x, self.bounds.width - 1))
        let clampedY = max(0, min(loc.y, self.bounds.height - 1))
        
        // Use renderer to convert valid point
        if let renderer = renderer, let (_, r, c) = renderer.convertPointToGrid(CGPoint(x: clampedX, y: clampedY)) {
            return (Int(r), Int(c))
        }
        
        // Fallback: If renderer fails (e.g. in padding), snap to nearest edge
        if let terminal = terminal {
            let matchesBottom = loc.y > self.bounds.height / 2
            let matchesRight = loc.x > self.bounds.width / 2
            
            let r = matchesBottom ? Int(aether_get_rows(terminal)) - 1 : 0
            let c = matchesRight ? Int(aether_get_cols(terminal)) - 1 : 0
            
            return (max(0, r), max(0, c))
        }
        
        return (0, 0)
    }
    
    func scrollTo(t: Double) {
        terminalSession.lock.lock()
        defer { terminalSession.lock.unlock() }
        
        // t: 0.0 (top/oldest) to 1.0 (bottom/newest)
        guard let terminal = terminal else { return }
        let info = aether_get_scroll_info(terminal)
        let maxScroll = Double(info.scrollback_rows)
        
        // Offset 0 = bottom (t=1.0)
        // Offset max = top (t=0.0)
        // offset = (1.0 - t) * maxScroll
        
        let newOffset = UInt32((1.0 - t) * maxScroll)
        aether_scroll_to(terminal, newOffset)
    }
    
    init(frame frameRect: CGRect, device: MTLDevice?, session: TerminalSession, onTitleChange: ((String) -> Void)? = nil) {
        print("[TerminalView] Init for Session #\(session.id)")
        self.terminalSession = session
        self.onTitleChange = onTitleChange
        super.init(frame: frameRect, device: device ?? MTLCreateSystemDefaultDevice())
        
        self.colorPixelFormat = .bgra8Unorm
        self.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        self.isPaused = false
        self.enableSetNeedsDisplay = false
        self.preferredFramesPerSecond = 30
        self.autoResizeDrawable = false 
        
        AetherBridge.registerCallbacks()
        // ... (env vars)
        setenv("TERM", "xterm-256color", 1)
        setenv("LANG", "en_US.UTF-8", 1)
        setenv("LC_ALL", "en_US.UTF-8", 1)
        setenv("COLORTERM", "truecolor", 1)
        
        // Init Metal Renderer
        do {
            self.renderer = try TerminalRenderer(metalView: self, session: session)
            self.delegate = self.renderer
        } catch {
            print("Failed to init renderer: \(error)")
        }
        
        // Terminal is now managed by session
        
        // Listen for scrollbar changes
        self.scrollState.userScrollRequest
            .sink { [weak self] t in
                guard let self = self else { return }
                self.scrollTo(t: t)
            }
            .store(in: &cancellables)
            
        // Observe tab title changes (for callback if needed, though TabBar observes directly)
        self.terminalSession.$title
            .sink { [weak self] newTitle in
                self?.onTitleChange?(newTitle)
            }
            .store(in: &cancellables)
            
        // Observe window title changes
        self.terminalSession.$windowTitle
            .sink { [weak self] newTitle in
                guard let self = self, self.isActive else { return }
                self.window?.title = newTitle
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleThemeChange(_:)), name: NSNotification.Name("AetherThemeChanged"), object: nil)
    }

    override var isOpaque: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureWindowAppearance()
        
        // Regain focus when added to window
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.window else { return }
            // Only auto-focus if this view is part of the active pane
            // But we don't strictly know if we are the active pane here easily without checking TabManager.
            if self.isActive {
                 // Explicitly claim focus if we are the active pane
                 window.makeFirstResponder(self)
            }

            // Force initial render
            // Ensure we have a valid size before calling renderer
            if self.frame.width > 0 && self.frame.height > 0 {
                self.layout() // Force layout pass to calculate drawableSize and notify renderer
            }
            self.setNeedsDisplay(self.bounds)
        }
    }
    
    private func configureWindowAppearance() {
        guard let window = self.window else { return }
        
        // Unified Title Bar Look
        // Content flows under title bar (.fullSizeContentView)
        // Title bar is transparent (we draw a blur view behind it in SwiftUI)
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden 
        
        // Initial title sync (we still set it for system features like Window menu)
        window.title = terminalSession.windowTitle
        
        window.isOpaque = false
        window.backgroundColor = .clear
        
        // Enable Native Fullscreen on separate desktop
        window.collectionBehavior = [.fullScreenPrimary, .managed]
        
        // Standard Green Button Behavior (Native Fullscreen)
        // Enabled by default if .resizable is in styleMask and .fullScreenPrimary collectionBehavior
        // We previously disabled it here, now we just let it be.
        
        // Enforce Minimum Window Size to prevent layout crashes
        window.minSize = NSSize(width: 800, height: 600)
        
        self.layer?.isOpaque = false
    }
        
    func updateConfig(_ config: AetherConfig) {
        guard let window = self.window else { return }
        window.alphaValue = CGFloat(config.window.opacity)
        
        switch config.window.titleBar {
        case .hidden:
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
        case .native:
            window.titleVisibility = .visible
            window.titlebarAppearsTransparent = false
        case .transparent:
            window.titleVisibility = .hidden // Changed from .visible to support custom centered title
            window.titlebarAppearsTransparent = true
        }
    }
    
    /// Called by AppKit when the view's backing store properties change — this is the
    /// canonical way to detect display DPI changes (plugging/unplugging external monitors,
    /// dragging a window between Retina and non-Retina displays, etc.).
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        guard let window = self.window else { return }

        let newScale = window.backingScaleFactor
        print("[TerminalView] Backing properties changed, new backingScaleFactor: \(newScale)")

        // Update Metal layer scale immediately
        self.layer?.contentsScale = newScale

        // Force a layout pass which will detect the scale change via lastBackingScale
        // and trigger the full resize → atlas recreation path (with proper locking).
        self.needsLayout = true
    }

    // Observer for theme changes
    @objc private func handleThemeChange(_ notification: Notification) {
        guard let name = notification.object as? String, let renderer = renderer else { return }
        renderer.setTheme(name)
        
        // Update background color from theme
        let theme = ConfigManager.shared.config.colors.resolveTheme()
        if let bg = parseColor(theme.background) {
            self.clearColor = bg
        } else {
             // Fallback for "Default" transparent
             self.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0.0)
        }
        
        self.setNeedsDisplay(self.bounds)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        // Terminal lifecycle is managed by TerminalSession
    }
    
    // Helper to reuse ConfigManager's parsing logic logic locally or just adding minimal one here
    private func parseColor(_ hex: String) -> MTLClearColor? {
        let argb = ConfigManager.shared.parseColor(hex)
        let a = Double((argb >> 24) & 0xFF) / 255.0
        let r = Double((argb >> 16) & 0xFF) / 255.0
        let g = Double((argb >> 8) & 0xFF) / 255.0
        let b = Double(argb & 0xFF) / 255.0
        return MTLClearColor(red: r, green: g, blue: b, alpha: a)
    }
    
    override func keyDown(with event: NSEvent) {
        lastInputTime = CACurrentMediaTime()
        renderer?.updateLastInputTime(lastInputTime)
        
        let modifiers = event.modifierFlags
        
        // 1. Resolve Key Binding
        if let keyStr = keyString(for: event) {
            // Priority: Session Restore Shortcut
            if keyStr == ConfigManager.shared.config.session.restoreShortcut {
                if performAction("restore_session") {
                    return
                }
            }
            
            if let action = ConfigManager.shared.config.keys.bindings[keyStr] {
                if performAction(action) {
                    return
                }
            }
        }
        
        // 2. Default Input Handling
        // Key Mapping
        switch event.keyCode {
        case 36:  sendBytes([0x0D])
        case 51:  sendBytes([0x7F])
        case 53:  sendBytes([0x1B])
        case 48:  sendBytes([0x09])
        case 126, 125, 124, 123: // Arrow Keys
            if modifiers.contains(.shift) && ConfigManager.shared.config.behavior.keyboardSelection {
                handleKeyboardSelection(keyCode: event.keyCode)
                return
            }
            // Clear selection on normal arrow move
            aether_selection_clear(terminal)
            keyboardSelectionAnchor = nil
            keyboardSelectionActive = nil
            renderer?.cursorOverride = nil
            
            switch event.keyCode {
            case 126: sendBytes([0x1B, 0x5B, 0x41])
            case 125: sendBytes([0x1B, 0x5B, 0x42])
            case 124: sendBytes([0x1B, 0x5B, 0x43])
            case 123: sendBytes([0x1B, 0x5B, 0x44])
            default: break
            }
        case 115: sendBytes([0x1B, 0x5B, 0x48])
        case 119: sendBytes([0x1B, 0x5B, 0x46])
        case 116: sendBytes([0x1B, 0x5B, 0x35, 0x7E])
        case 121: sendBytes([0x1B, 0x5B, 0x36, 0x7E])
        case 117: sendBytes([0x1B, 0x5B, 0x33, 0x7E])
        default:
            if modifiers.contains(.control), let chars = event.charactersIgnoringModifiers {
                if let char = chars.unicodeScalars.first {
                    let code = char.value
                    if code >= 0x61 && code <= 0x7A {
                        sendBytes([UInt8(code - 0x60)])
                        return
                    }
                    if code == 0x5B {
                        sendBytes([0x1B])
                        return
                    }
                }
            }
            if let chars = event.characters {
                sendBytes(Array(chars.utf8))
            }
        }
        
        self.setNeedsDisplay(self.bounds)
    }
    
    private func handleKeyboardSelection(keyCode: UInt16) {
        terminalSession.lock.lock()
        defer { terminalSession.lock.unlock() }
        
        guard let terminal = terminal else { return }
        
        // Initialize anchor if needed
        if keyboardSelectionAnchor == nil {
            let cursor = aether_get_cursor(terminal)
            keyboardSelectionAnchor = (cursor.row, cursor.col)
            keyboardSelectionActive = (cursor.row, cursor.col)
            aether_selection_start(terminal, cursor.row, cursor.col)
        }
        
        guard var active = keyboardSelectionActive else { return }
        
        // Update active point
        let maxRows = aether_get_rows(terminal)
        let maxCols = aether_get_cols(terminal)
        
        switch keyCode {
        case 126: // Up
            if active.row > 0 { active.row -= 1 }
        case 125: // Down
            if active.row < maxRows - 1 { active.row += 1 }
        case 124: // Right
            if active.col < maxCols - 1 { active.col += 1 }
            else if active.row < maxRows - 1 {
                active.col = 0
                active.row += 1
            }
        case 123: // Left
            if active.col > 0 { active.col -= 1 }
            else if active.row > 0 {
                active.col = maxCols - 1
                active.row -= 1
            }
        default: break
        }
        
        keyboardSelectionActive = active
        // Override cursor position for visual feedback
        renderer?.cursorOverride = active
        aether_selection_drag(terminal, active.row, active.col)
        self.setNeedsDisplay(self.bounds)
    }
    
    private func sendBytes(_ bytes: [UInt8]) {
        terminalSession.notifyInteraction()
        terminalSession.lock.lock()
        defer { terminalSession.lock.unlock() }
        
        guard let terminal = terminal else { return }
        bytes.withUnsafeBufferPointer { ptr in
            if let base = ptr.baseAddress {
                _ = aether_write_input(terminal, base, ptr.count)
            }
        }
    }
    
    // --- Mouse Handling ---
    
    override func mouseDown(with event: NSEvent) {
        // Explicitly claim focus
        self.window?.makeFirstResponder(self)
        onSelect?()
        
        terminalSession.lock.lock()
        defer { terminalSession.lock.unlock() }
        
        keyboardSelectionAnchor = nil
        keyboardSelectionActive = nil
        renderer?.cursorOverride = nil
        
        let point = self.convert(event.locationInWindow, from: nil)
        guard let terminal = terminal, let renderer = renderer else { return }
        
        if let (_, r, c) = renderer.convertPointToGrid(point) {
            // Check if application wants mouse events
            if aether_mouse_event(terminal, 0, true, r, c, false) {
                self.setNeedsDisplay(self.bounds)
                return
            }
            
            aether_selection_start(terminal, r, c)
            self.setNeedsDisplay(self.bounds)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        terminalSession.lock.lock()
        defer { terminalSession.lock.unlock() }
        
        let point = self.convert(event.locationInWindow, from: nil)
        guard let terminal = terminal, let renderer = renderer else { return }
        
        if let (_, r, c) = renderer.convertPointToGrid(point) {
            // Release event (Button 0)
            if aether_mouse_event(terminal, 0, false, r, c, hasMouseDragged) {
                 self.setNeedsDisplay(self.bounds)
                 hasMouseDragged = false
                 return
            }
            
            aether_selection_end(terminal, r, c)
        }
        
        if event.clickCount == 1 && !hasMouseDragged {
            aether_selection_clear(terminal)
        }
        hasMouseDragged = false
        self.setNeedsDisplay(self.bounds)
    }
    
    private func copySelection() {
        terminalSession.lock.lock()
        defer { terminalSession.lock.unlock() }
        
        guard let terminal = terminal else { return }
        if let ptr = aether_get_selection(terminal) {
             let str = String(cString: ptr)
             aether_free_string(ptr)
             
             if !str.isEmpty {
                 let board = NSPasteboard.general
                 board.clearContents()
                 board.setString(str, forType: .string)
             }
        }
    }
    private func performAction(_ action: String) -> Bool {
        switch action {
        case "copy":
            copySelection()
            return true
        case "paste":
            let board = NSPasteboard.general
            if let str = board.string(forType: .string) {
                terminalSession.lock.lock()
                let bracketed = aether_is_bracketed_paste(terminal)
                terminalSession.lock.unlock()
                
                var payload = str
                if bracketed {
                    // Security: Strip existing bracketed-paste-end markers to prevent injection
                    let clean = str.replacingOccurrences(of: "\u{1b}[201~", with: "")
                    payload = "\u{1b}[200~\(clean)\u{1b}[201~"
                }
                sendBytes(Array(payload.utf8))
            }
            return true
        case "toggle_fullscreen":
            return onAction?("toggle_fullscreen") ?? false
        case "new_tab":
            return onAction?("new_tab") ?? false
        case "close_tab":
            return onAction?("close_tab") ?? false
        case "new_window":
            print("Action not implemented yet: \(action)")
            return true
        case "restore_session":
            return onAction?("restore_session") ?? false
        case "split_horizontal", "split_vertical", "close_pane", "enter_window_mode", 
             "focus_left", "focus_right", "focus_up", "focus_down":
            return onAction?(action) ?? false
        default:
            return false
        }
    }
    
    private func keyString(for event: NSEvent) -> String? {
        var str = ""
        let mod = event.modifierFlags
        
        if mod.contains(.command) { str += "cmd+" }
        if mod.contains(.control) { str += "ctrl+" }
        if mod.contains(.option) { str += "opt+" }
        if mod.contains(.shift) { str += "shift+" }
        
        if let char = event.charactersIgnoringModifiers?.lowercased() {
             if event.keyCode == 36 { return str + "enter" }
             if event.keyCode == 53 { return str + "esc" }
             if event.keyCode == 48 { return str + "tab" }
             if event.keyCode == 51 { return str + "backspace" }
             
             if event.keyCode == 123 { return str + "left" }
             if event.keyCode == 124 { return str + "right" }
             if event.keyCode == 125 { return str + "down" }
             if event.keyCode == 126 { return str + "up" }
             
             if !char.isEmpty {
                 return str + char
             }
        }
        return nil
    }
}

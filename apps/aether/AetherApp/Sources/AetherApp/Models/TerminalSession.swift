import Foundation
import CAether
import Combine

class TerminalSession: Identifiable, ObservableObject {
    let id: UUID
    @Published var title: String
    @Published var windowTitle: String = "Aether"
    @Published var isLoading: Bool = true
    @Published var currentCwd: String?
    
    private(set) var terminal: OpaquePointer?
    let scrollState: TerminalScrollState
    private var isClosing = false
    
    // Notify when user does something (typing, clicking)
    let userInteractionOccurred = PassthroughSubject<Void, Never>()
    
    // Publishes raw terminal output text for AI copilot triggers
    let rawOutputSubject = PassthroughSubject<String, Never>()
    
    // Shared lock for synchronizing access to the terminal pointer (Zig backend)
    // Used by both TerminalSession (polling) and TerminalRenderer (drawing/resizing)
    public let lock = NSRecursiveLock()
    
    init(cwd: String? = nil) {
        self.id = UUID()
        self.title = "Terminal"
        self.windowTitle = "Aether"
        self.scrollState = TerminalScrollState()
        
        print("[TerminalSession] Init \(self.id)")
        
        // Set environment variables before spawning PTY
        setenv("TERM", "xterm-256color", 1)
        setenv("COLORTERM", "truecolor", 1)
        setenv("LANG", "en_US.UTF-8", 1)
        setenv("LC_ALL", "en_US.UTF-8", 1)

        // Initialize backend terminal
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let initialCwd = cwd ?? home
        
        let ctrlcSigint = ConfigManager.shared.config.behavior.ctrlcSendsSigint
        let scrollbackLimit = ConfigManager.shared.config.terminal.scrollbackLimit
        
        // Convert cwd to unsafe pointer if needed or just pass string
        // aether_terminal_with_pty takes [*:0]const u8
        self.terminal = initialCwd.withCString { cwdPtr in
             return aether_terminal_with_pty(24, 80, UInt32(scrollbackLimit), nil, cwdPtr, ctrlcSigint)
        }
        
        self.currentCwd = initialCwd
        
        startPolling()
    }
    
    deinit {
        print("[TerminalSession] Deinit \(self.id)")
        
        lock.lock()
        isClosing = true
        let termToFree = terminal
        self.terminal = nil
        self.currentCwd = nil
        lock.unlock()
        
        stopPolling()
        
        if let term = termToFree {
            aether_terminal_free(term)
        }
    }
    
    func notifyInteraction() {
        userInteractionOccurred.send()
    }
    
    // MARK: - Input
    
    /// Write a string to the terminal's PTY input.
    func writeInput(_ string: String) {
        lock.lock()
        defer { lock.unlock() }
        
        guard let term = terminal, !isClosing else { return }
        guard let data = string.data(using: .utf8) else { return }
        data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            if let baseAddress = ptr.baseAddress {
                _ = aether_write_input(term, baseAddress.assumingMemoryBound(to: UInt8.self), ptr.count)
            }
        }
    }

    func resize(cols: Int, rows: Int) {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isClosing, let term = terminal else { return }
        _ = aether_resize(term, UInt32(rows), UInt32(cols))
    }

    // Polling for title
    private var timer: Timer?
    private var ioWorkItem: DispatchWorkItem?
    
    func startPolling() {
        // Title Polling (Low Frequency)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, !self.isClosing else { return }
            self.updateTitle()
        }
        
        // I/O Polling (High Frequency / Continuous)
        // We use a background thread to continuously read from the PTY and update the Grid.
        // This decouples parsing from the UI thread (Renderer).
        let workItem = DispatchWorkItem { [weak self] in
            while let self = self {
                if self.isClosing { break }
                if let item = self.ioWorkItem, item.isCancelled { break }
                self.processIO()
                Thread.sleep(forTimeInterval: 0.005)
            }
        }
        self.ioWorkItem = workItem
        DispatchQueue.global(qos: .userInteractive).async(execute: workItem)
    }
    
    func stopPolling() {
        timer?.invalidate()
        timer = nil
        ioWorkItem?.cancel()
        ioWorkItem = nil
    }
    
    private func processIO() {
        lock.lock()
         // We do NOT defer unlock here because we might want to notify UI *after* unlock to avoid holding it?
         // No, standard defer is safer.
        defer { lock.unlock() }
        
        guard let term = terminal else { return }
        
        // This reads from PTY, runs Parser, updates Grid.
        // It is FAST for small chunks, but can block if we process megabytes.
        // Since we are in background, we don't block UI.
        aether_process_output(term)
        
        // Mark as loaded once we get any output from the shell that modifies the grid
        // Reverting to wait for actual visual changes to avoid "trash" black screen snapping
        if self.isLoading && aether_is_dirty(term) {
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
        
        // Emit raw output for AI copilot hooks (only when new data arrived)
        if aether_is_dirty(term) {
            let rows = aether_get_rows(term)
            let cols = aether_get_cols(term)
            // Read last 3 rows only — enough for "command not found" detection without overhead
            let startRow = rows > 3 ? rows - 3 : 0
            var output = ""
            for r in startRow..<rows {
                for c in 0..<cols {
                    if let cellPtr = aether_get_cell(term, r, c) {
                        let cp = cellPtr.pointee.codepoint
                        if cp > 0, let scalar = Unicode.Scalar(cp) {
                            output.append(Character(scalar))
                        }
                    }
                }
                output.append("\n")
            }
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                DispatchQueue.main.async {
                    self.rawOutputSubject.send(trimmed)
                }
            }
        }
        
        // If dirty, we should notify the view to redraw.
        // Since TerminalSession is ObservableObject, we can't easily publish on background thread without main dispatch.
        // But Renderer checks `forceNextFrame` or similar.
        // How do we tell Renderer "New Data"?
        // Renderer pulls `aether_get_cell` every frame (60fps).
        // If we just update the grid, the next frame will pick it up.
        // So explicit notification is only needed if Renderer is PAUSED (sleeping).
        // Assuming Renderer runs animation loop?
        // Renderer.draw is called by MTKView.
        // If users reports "manageable in normal mode", MTKView is likely running.
        // So we just update the data.
    }
    
    private func updateTitle() {
        lock.lock()
        defer { lock.unlock() }
        
        guard let term = terminal else { return }
        let pid = aether_get_pid(term)
        if pid <= 0 { return }
        
        // 1. Get TTY & CWD
        var ttyBuf = [Int8](repeating: 0, count: 64)
        _ = aether_get_tty(term, &ttyBuf, 64)
        let ttyName = String(cString: ttyBuf)
        
        var cwdBuf = [Int8](repeating: 0, count: 1024)
        _ = aether_get_cwd(pid, &cwdBuf, 1024)
        let cwdPath = String(cString: cwdBuf)
        
        DispatchQueue.main.async {
            if self.currentCwd != cwdPath {
                self.currentCwd = cwdPath
            }
        }
        
        // Window Title Logic (User@Host:PWD)
        let user = NSUserName()
        let host = ProcessInfo.processInfo.hostName
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let displayPath = cwdPath.replacingOccurrences(of: home, with: "~")
        let longTitle = "\(user)@\(host):\(displayPath)"
                // Tab Title Logic (Process Name)
        let cleanTty = ttyName.replacingOccurrences(of: "/dev/", with: "")
        
         if !cleanTty.isEmpty {
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self = self, !self.isClosing else { return }
                
                // Tab Title Logic
                // User wants "only the last folder name" for path-based titles.
                let cwdUrl = URL(fileURLWithPath: cwdPath)
                let folderName = cwdPath == "/" ? "/" : cwdUrl.lastPathComponent
                
                // Get Process Name
                var shortTitle = "Terminal"
                if let proc = self.getForegroundProcess(tty: cleanTty) {
                     shortTitle = proc
                }
                
                let style = ConfigManager.shared.config.ui.tabs.titleStyle
                var tabTitle = shortTitle
                
                if style == .path {
                    tabTitle = folderName // Was displayPath
                } else if style == .smart {
                     if let name = self.getForegroundProcess(tty: cleanTty), !name.contains("login"), !name.contains("-zsh"), !name.contains("zsh") {
                         tabTitle = name
                     } else {
                         // Fallback to Folder Name
                         tabTitle = folderName
                     }
                } else {
                    // .process
                    tabTitle = shortTitle
                }
                
                DispatchQueue.main.async {
                    guard !self.isClosing else { return }
                    if self.title != tabTitle {
                        self.title = tabTitle
                    }
                    if self.windowTitle != longTitle {
                        self.windowTitle = longTitle
                    }
                }
            }
        }
    }
    
    private func getForegroundProcess(tty: String) -> String? {
        // Run ps -t <tty> -o state,comm
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-t", tty, "-o", "state,comm"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: .newlines)
                // Skip header. Look for '+' in state column.
                // Output format:
                // STATE COMM
                // S+    /bin/zsh
                // R+    vim
                
                for line in lines.dropFirst() {
                    let trim = line.trimmingCharacters(in: .whitespaces)
                    if trim.isEmpty { continue }
                    
                    if trim.starts(with: "R+") || trim.contains("+") {
                        // Extract command
                        // Split by space? 'S+ /bin/zsh' -> ['S+', '/bin/zsh']
                        // But command can have spaces? `ps -o comm` usually gives command name/path.
                        // `state` is single word.
                        
                        // Simple parse: find first space
                        if let range = trim.range(of: " ") {
                            let state = trim[..<range.lowerBound]
                            if state.contains("+") {
                                let comm = trim[range.upperBound...].trimmingCharacters(in: .whitespaces)
                                return URL(fileURLWithPath: comm).lastPathComponent
                            }
                        }
                    }
                }
            }
        } catch {
            print("Failed to run ps: \(error)")
        }
        return nil
    }
    
    // MARK: - Context for AI
    
    /// Get recent visible terminal content as text for AI context.
    func getRecentContext(lines: Int) -> String {
        lock.lock()
        defer { lock.unlock() }
        
        guard let term = terminal else { return "" }
        
        let rows = Int(aether_get_rows(term))
        let cols = Int(aether_get_cols(term))
        let linesToRead = min(lines, rows)
        let startRow = max(0, rows - linesToRead)
        
        var result: [String] = []
        
        for r in startRow..<rows {
            var line = ""
            for c in 0..<cols {
                if let cellPtr = aether_get_cell(term, UInt32(r), UInt32(c)) {
                    let cp = cellPtr.pointee.codepoint
                    if cp > 0, let scalar = Unicode.Scalar(cp) {
                        line.append(Character(scalar))
                    } else {
                        line.append(" ")
                    }
                }
            }
            // Trim trailing whitespace per line
            result.append(line.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression))
        }
        
        return result.joined(separator: "\n")
    }
    
    // MARK: - History
    
    func getHistory() -> [SavedRow] {
        lock.lock()
        defer { lock.unlock() }
        
        guard let term = terminal else { return [] }
        
        let count = aether_terminal_get_history_count(term)
        let cols = aether_get_cols(term)
        var history: [SavedRow] = []
        
        // Cap to maxHistoryRows to keep session files small
        let limit = UInt32(SavedPane.maxHistoryRows)
        let start = count > limit ? count - limit : 0
        
        var cellBuf = [AetherCell](repeating: AetherCell(), count: Int(cols))
        
        for i in start..<count {
            if aether_terminal_get_history_row(term, i, &cellBuf) {
                let metadata = aether_terminal_get_row_metadata(term, i)
                
                let savedCells = cellBuf.map { cell in
                    SavedCell(cp: cell.codepoint, fg: cell.fg_color, bg: cell.bg_color, f: cell.flags)
                }
                
                // Pack cells into binary Data for compact storage
                let packedData = SavedRow.pack(cells: savedCells)
                history.append(SavedRow(cellData: packedData, wrapped: metadata.wrapped))
            }
        }
        
        return history
    }
    
    func restoreHistory(_ history: [SavedRow]) {
        lock.lock()
        defer { lock.unlock() }
        
        guard let term = terminal else { return }
        
        aether_terminal_clear_history(term)
        
        for row in history {
            // Unpack binary cell data back into AetherCell array
            let savedCells = row.unpackCells()
            let aetherCells = savedCells.map { cell in
                AetherCell(codepoint: cell.cp, fg_color: cell.fg, bg_color: cell.bg, flags: cell.f, semantic_id: 0)
            }
            
            _ = aether_terminal_append_history_row(term, aetherCells, UInt32(aetherCells.count), row.wrapped, false)
        }
    }
}

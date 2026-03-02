import Foundation
import SwiftUI
import Combine

class SessionManager: ObservableObject {
    static let shared = SessionManager()
    
    @Published var savedSessions: [SavedSessionState] = []
    @Published var isLoaded: Bool = false
    
    // Weak reference to the active TabManager to allow saving from AppDelegate
    weak var tabManager: TabManager?
    
    private let maxSessions: Int = 10
    private let fileName = "sessions.plist"
    private let lock = NSLock()
    private var isSaving = false
    
    private var fileURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let folder = appSupport.appendingPathComponent("Aether")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(fileName)
        return url
    }
    
    init() {
        // Do NOT load sessions here — call loadAsync() explicitly to avoid blocking main thread
    }
    
    // MARK: - Async Load
    
    /// Load sessions from disk on a background queue. Updates `isLoaded` on main thread when done.
    func loadAsync() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.loadSessionsFromDisk()
        }
    }
    
    private func loadSessionsFromDisk() {
        guard let url = fileURL else {
            DispatchQueue.main.async { self.isLoaded = true }
            return
        }
        if !FileManager.default.fileExists(atPath: url.path) {
            print("[SessionManager] No saved sessions file found at \(url.path)")
            DispatchQueue.main.async { self.isLoaded = true }
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoded = try PropertyListDecoder().decode([SavedSessionState].self, from: data)
            let sorted = decoded.sorted { $0.timestamp > $1.timestamp }
            print("[SessionManager] Loaded \(sorted.count) sessions from disk (\(data.count) bytes).")
            DispatchQueue.main.async {
                self.savedSessions = sorted
                self.isLoaded = true
            }
        } catch {
            print("[SessionManager] Failed to load: \(error)")
            // Try legacy JSON fallback
            self.tryLoadLegacyJSON()
        }
    }
    
    /// One-time fallback: try loading old sessions.json if sessions.plist doesn't exist yet.
    private func tryLoadLegacyJSON() {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            DispatchQueue.main.async { self.isLoaded = true }
            return
        }
        let legacyURL = appSupport.appendingPathComponent("Aether").appendingPathComponent("sessions.json")
        guard FileManager.default.fileExists(atPath: legacyURL.path) else {
            DispatchQueue.main.async { self.isLoaded = true }
            return
        }
        
        print("[SessionManager] Attempting legacy JSON migration...")
        // We can't easily decode legacy format since SavedRow changed.
        // Just clean start — delete the old file to avoid confusion.
        try? FileManager.default.removeItem(at: legacyURL)
        print("[SessionManager] Removed legacy sessions.json. Starting fresh.")
        DispatchQueue.main.async { self.isLoaded = true }
    }
    
    // MARK: - Save
    
    func saveSession(tabs: [Tab], activeTabId: UUID?) {
        lock.lock()
        defer { lock.unlock() }
        
        let savedTabs = tabs.map { convert(tab: $0) }
        
        let newState = SavedSessionState(
            timestamp: Date(),
            tabs: savedTabs,
            activeTabId: activeTabId
        )
        
        // Update state and persist immediately
        var newSessions = [newState] + self.savedSessions
        if newSessions.count > self.maxSessions {
            newSessions = Array(newSessions.prefix(self.maxSessions))
        }
        
        self.savedSessions = newSessions
        
        // Persist on background thread to avoid blocking UI
        let sessionsToSave = newSessions
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.persistToDisk(sessions: sessionsToSave)
        }
    }
    
    private func persistToDisk(sessions: [SavedSessionState]) {
        guard let url = fileURL else { return }
        do {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            let data = try encoder.encode(sessions)
            try data.write(to: url)
            print("[SessionManager] Saved \(sessions.count) sessions to \(url.path) (\(data.count) bytes)")
        } catch {
            print("[SessionManager] Failed to save: \(error)")
        }
    }
    
    // MARK: - Restore
    
    func restoreLastSession() -> SavedSessionState? {
        return savedSessions.sorted { $0.timestamp > $1.timestamp }.first
    }
    
    // MARK: - Converters
    
    private func convert(tab: Tab) -> SavedTab {
        return SavedTab(
            id: tab.id,
            title: tab.title,
            root: convert(node: tab.root),
            activePaneId: tab.activePaneId
        )
    }
    
    private func convert(node: PaneNode) -> SavedPaneNode {
        switch node {
        case .pane(let pane):
            // Safety check: if session is still loading or terminal is gone, don't try to get history
            let history = pane.session.isLoading ? [] : pane.session.getHistory()
            
            // Cap history to maxHistoryRows to keep file size small
            let cappedHistory: [SavedRow]
            if history.count > SavedPane.maxHistoryRows {
                cappedHistory = Array(history.suffix(SavedPane.maxHistoryRows))
            } else {
                cappedHistory = history
            }
            
            return .pane(SavedPane(
                id: pane.id,
                cwd: getCwd(for: pane.session),
                title: pane.session.title,
                history: cappedHistory
            ))
        case .split(let id, let axis, let first, let second, let loc):
            return .split(
                id: id,
                axis: axis,
                first: convert(node: first),
                second: convert(node: second),
                splitLocation: loc
            )
        }
    }
    
    // MARK: - Helpers
    
    private func getCwd(for session: TerminalSession) -> String {
        return session.currentCwd ?? FileManager.default.homeDirectoryForCurrentUser.path
    }
}

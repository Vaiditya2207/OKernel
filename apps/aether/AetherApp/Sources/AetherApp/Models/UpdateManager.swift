import Foundation
import Combine
import AppKit

/// Numeric semantic versioning (major.minor.patch)
struct SemanticVersion: Comparable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int
    let originalString: String

    init?(_ versionString: String) {
        let cleaned = versionString.hasPrefix("v") ? String(versionString.dropFirst()) : versionString
        let parts = cleaned.split(separator: ".").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        
        // Support 1.0, 1.0.0, etc.
        guard parts.count >= 2 else { return nil }
        
        self.major = parts[0]
        self.minor = parts[1]
        self.patch = parts.count > 2 ? parts[2] : 0
        self.originalString = versionString
    }

    var description: String { originalString }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }

    static func == (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        return lhs.major == rhs.major && lhs.minor == rhs.minor && lhs.patch == rhs.patch
    }
}

/// Metadata returned by GET /api/v1/aether/latest
struct AetherVersionInfo: Codable {
    let version: String
    let description: String
    let changelog: String
    let releaseDate: String
    let size: Int64
    let bundleFilename: String?
    let bundleSize: Int64?

    enum CodingKeys: String, CodingKey {
        case version, description, changelog, size
        case releaseDate = "release_date"
        case bundleFilename = "bundle_filename"
        case bundleSize = "bundle_size"
    }
}

class UpdateManager: NSObject, ObservableObject {
    static let shared = UpdateManager()
    
    @Published var state: UpdateState = .idle
    @Published var availableVersion: AetherVersionInfo?
    @Published var downloadProgress: Double = 0.0
    @Published var statusMessage: String = ""
    @Published var showModal: Bool = false
    
    private var checkTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    enum UpdateState: Equatable {
        case idle
        case checking
        case available(version: String)
        case downloading
        case readyToInstall
        case installing
        case failed(error: String)
        case restartRequired
        
        var isProgressState: Bool {
            if case .downloading = self { return true }
            if case .installing = self { return true }
            return false
        }
        
        var isFailedState: Bool {
            if case .failed = self { return true }
            return false
        }
    }
    
    var isFailedState: Bool { state.isFailedState }
    
    private var downloadTask: URLSessionDownloadTask?
    private lazy var downloadSession: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()

    override private init() {
        super.init()
        // Log current version for debugging
        if let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            print("[UpdateManager] Current version: \(currentVersion)")
        }
    }
    
    func schedulePeriodicCheck() {
        checkTimer?.invalidate()
        
        let config = ConfigManager.shared.config.update
        guard config.enabled else {
            print("[UpdateManager] Updates disabled in config.")
            return
        }
        
        // Initial check
        checkForUpdates()
        
        // Schedule repeats
        let interval = TimeInterval(config.checkInterval)
        checkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkForUpdates()
        }
        print("[UpdateManager] Scheduled periodic check every \(config.checkInterval)s")
    }
    
    func checkForUpdates() {
        let config = ConfigManager.shared.config.update
        guard config.enabled else { return }
        
        // Don't interrupt active update flow
        let canCheck = state == .idle || state == .checking || isFailedState
        guard canCheck else { return }
        
        state = .checking
        
        guard let url = URL(string: "\(config.serverUrl)/api/v1/aether/latest") else {
            state = .failed(error: "Invalid server URL: \(config.serverUrl)")
            return
        }
        
        print("[UpdateManager] Checking for updates at \(url.absoluteString)...")
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: AetherVersionInfo.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    print("[UpdateManager] Check failed: \(error.localizedDescription)")
                    self.state = .idle 
                }
            } receiveValue: { info in
                self.processVersionInfo(info)
            }
            .store(in: &cancellables)
    }
    
    private func processVersionInfo(_ info: AetherVersionInfo) {
        guard let remoteVer = SemanticVersion(info.version),
              let currentStr = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let currentVer = SemanticVersion(currentStr) else {
            print("[UpdateManager] Failed to parse version strings: remote=\(info.version)")
            state = .idle
            return
        }
        
        if remoteVer > currentVer {
            print("[UpdateManager] New version available: \(info.version) (current: \(currentStr))")
            self.availableVersion = info
            self.state = .available(version: info.version)
        } else {
            print("[UpdateManager] Up to date (remote=\(info.version), current=\(currentStr))")
            self.state = .idle
        }
    }
    
    // MARK: - Phase 4: Download
    
    func downloadUpdate() {
        guard let info = availableVersion else { return }
        let config = ConfigManager.shared.config.update
        
        guard let url = URL(string: "\(config.serverUrl)/api/v1/aether/download/bundle?v=\(info.version)") else {
            state = .failed(error: "Invalid download URL")
            return
        }
        
        state = .downloading
        downloadProgress = 0.0
        
        downloadTask = downloadSession.downloadTask(with: url)
        downloadTask?.resume()
        print("[UpdateManager] Started download: \(url.absoluteString)")
    }
    
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        state = .idle
        downloadProgress = 0.0
    }
    
    // MARK: - Phase 5: Install
    
    func applyUpdate() {
        guard let info = availableVersion else { return }
        state = .installing
        statusMessage = "Preparing installation..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.performInstallation(version: info.version)
        }
    }
    
    private func performInstallation(version: String) {
        let fileManager = FileManager.default
        let bundleURL = Bundle.main.bundleURL // /Applications/Aether.app
        let contentsURL = bundleURL.appendingPathComponent("Contents")
        
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let aetherDir = appSupport.appendingPathComponent("Aether")
        let updatesDir = aetherDir.appendingPathComponent("updates").appendingPathComponent(version)
        let backupDir = aetherDir.appendingPathComponent("backup")
        let tarballPath = updatesDir.appendingPathComponent("Aether-bundle-\(version).tar.gz")
        
        do {
            updateStatus("Checking permissions...")
            // 1. Verify we can write to bundle
            if !fileManager.isWritableFile(atPath: bundleURL.path) {
                throw UpdateError.notWritable("Aether is not in a writable location (e.g. /Applications with SIP). Please move it to your Applications folder or a user-writable directory.")
            }
            
            // 2. Backup
            updateStatus("Creating backup...")
            if fileManager.fileExists(atPath: backupDir.path) {
                try fileManager.removeItem(at: backupDir)
            }
            try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
            try fileManager.copyItem(at: contentsURL, to: backupDir.appendingPathComponent("Contents"))
            
            // 3. Extract
            updateStatus("Extracting update...")
            let tarProcess = Process()
            tarProcess.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            tarProcess.arguments = ["-xzf", tarballPath.path, "-C", bundleURL.path]
            try tarProcess.run()
            tarProcess.waitUntilExit()
            
            if tarProcess.terminationStatus != 0 {
                throw UpdateError.extractionFailed("Tar extraction failed with exit code \(tarProcess.terminationStatus)")
            }
            
            // 4. Re-sign (Ad-hoc)
            updateStatus("Verifying signature...")
            let signProcess = Process()
            signProcess.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
            signProcess.arguments = ["--force", "--deep", "--sign", "-", bundleURL.path]
            try signProcess.run()
            signProcess.waitUntilExit()
            
            // 5. Success
            updateStatus("Update complete!")
            
            // Record pending update for Phase 6 "What's New"
            UserDefaults.standard.set(version, forKey: "pendingUpdateVersion")
            if let changelog = availableVersion?.changelog {
                UserDefaults.standard.set(changelog, forKey: "pendingUpdateChangelog")
            }
            
            DispatchQueue.main.async {
                self.state = .restartRequired
            }
            
        } catch {
            print("[UpdateManager] Installation failed: \(error)")
            // Rollback
            try? fileManager.removeItem(at: contentsURL)
            try? fileManager.copyItem(at: backupDir.appendingPathComponent("Contents"), to: contentsURL)
            
            DispatchQueue.main.async {
                self.state = .failed(error: (error as? UpdateError)?.message ?? error.localizedDescription)
            }
        }
    }
    
    private func updateStatus(_ msg: String) {
        DispatchQueue.main.async {
            self.statusMessage = msg
        }
    }
    
    func restartApp() {
        let bundleURL = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { _, error in
            if let error = error {
                print("[UpdateManager] Failed to restart app: \(error)")
            } else {
                NSApp.terminate(nil)
            }
        }
    }
}

extension UpdateManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let info = availableVersion else { return }
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let updatesDir = appSupport.appendingPathComponent("Aether/updates/\(info.version)")
        let destination = updatesDir.appendingPathComponent("Aether-bundle-\(info.version).tar.gz")
        
        do {
            try fileManager.createDirectory(at: updatesDir, withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: location, to: destination)
            
            DispatchQueue.main.async {
                self.state = .readyToInstall
            }
        } catch {
            DispatchQueue.main.async {
                self.state = .failed(error: "Failed to save update: \(error.localizedDescription)")
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self.downloadProgress = progress
        }
    }
}

enum UpdateError: Error {
    case notWritable(String)
    case extractionFailed(String)
    
    var message: String {
        switch self {
        case .notWritable(let m): return m
        case .extractionFailed(let m): return m
        }
    }
}

// Helper for switch case matching on Equatable enum with associated values
func ==(lhs: UpdateManager.UpdateState, rhs: UpdateManager.UpdateState) -> Bool {
    switch (lhs, rhs) {
    case (.idle, .idle): return true
    case (.checking, .checking): return true
    case (.available(let v1), .available(let v2)): return v1 == v2
    case (.downloading, .downloading): return true
    case (.readyToInstall, .readyToInstall): return true
    case (.installing, .installing): return true
    case (.failed(let e1), .failed(let e2)): return e1 == e2
    case (.restartRequired, .restartRequired): return true
    default: return false
    }
}

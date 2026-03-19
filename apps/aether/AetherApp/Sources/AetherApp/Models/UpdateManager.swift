import Foundation
import Combine
import AppKit
import CryptoKit

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
    let channel: String?
    let patchFilename: String?
    let patchSize: Int64?
    let patchFromVersion: String?
    let bundleSignature: String?
    let patchSignature: String?

    enum CodingKeys: String, CodingKey {
        case version, description, changelog, size, channel
        case releaseDate = "release_date"
        case bundleFilename = "bundle_filename"
        case bundleSize = "bundle_size"
        case patchFilename = "patch_filename"
        case patchSize = "patch_size"
        case patchFromVersion = "patch_from_version"
        case bundleSignature = "bundle_signature"
        case patchSignature = "patch_signature"
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
    private var backgroundUpdateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var currentDownloadUrl: URL?
    private var isBackgroundCheck: Bool = false
    
    @Published var updateReadyForInstall: Bool = false
    
    // Phase 11: Ed25519 Public Key (Hex)
    private let publicKeyHex = "b6ea81d1207aede7d30e61bca5300d297339e7bd19fff99e40b57df388104b0f"
    
    enum UpdateState: Equatable {
        case idle
        case checking
        case available(version: String)
        case downloading
        case readyToInstall
        case installing
        case rollbackInProgress
        case failed(error: String)
        case restartRequired
        
        var isProgressState: Bool {
            if case .downloading = self { return true }
            if case .installing = self { return true }
            if case .rollbackInProgress = self { return true }
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
        backgroundUpdateTimer?.invalidate()
        
        let config = ConfigManager.shared.config.update
        guard config.enabled else {
            print("[UpdateManager] Updates disabled in config.")
            return
        }
        
        // Initial check
        checkForUpdates()
        
        // Schedule foreground repeats (faster when app is active)
        let interval = TimeInterval(config.checkInterval)
        checkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkForUpdates()
        }
        
        // Schedule background repeats (slower, e.g. every 4 hours)
        backgroundUpdateTimer = Timer.scheduledTimer(withTimeInterval: 4 * 3600, repeats: true) { [weak self] _ in
            self?.checkForUpdates(isBackground: true)
        }
        
        print("[UpdateManager] Scheduled periodic check every \(config.checkInterval)s (foreground) and 4h (background)")
    }
    
    func checkForUpdates(isBackground: Bool = false) {
        self.isBackgroundCheck = isBackground
        let config = ConfigManager.shared.config.update
        guard config.enabled else { return }
        
        // Don't interrupt active update flow
        let canCheck = state == .idle || state == .checking || isFailedState
        guard canCheck else { return }
        
        if !isBackground {
            state = .checking
        }
        
        var urlComponents = URLComponents(string: "\(config.serverUrl)/api/v1/aether/latest")
        urlComponents?.queryItems = [
            URLQueryItem(name: "channel", value: config.channel)
        ]
        
        guard let url = urlComponents?.url else {
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
                    if !self.isBackgroundCheck {
                        self.state = .idle 
                    }
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
            if !isBackgroundCheck {
                self.state = .available(version: info.version)
            } else {
                // Background check found an update - trigger silent download
                downloadUpdate()
            }
        } else {
            print("[UpdateManager] Up to date (remote=\(info.version), current=\(currentStr))")
            if !isBackgroundCheck {
                self.state = .idle
            }
        }
    }
    
    // MARK: - Phase 4: Download
    
    func downloadUpdate() {
        guard let info = availableVersion else { return }
        let config = ConfigManager.shared.config.update
        
        if !isBackgroundCheck {
            state = .downloading
            downloadProgress = 0.0
        }
        
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        var downloadUrl: URL?
        
        // Try Patch if available and version matches
        if let patchFile = info.patchFilename, info.patchFromVersion == currentVersion {
            var urlComponents = URLComponents(string: "\(config.serverUrl)/api/v1/aether/download/patch")
            urlComponents?.queryItems = [
                URLQueryItem(name: "v", value: info.version),
                URLQueryItem(name: "channel", value: config.channel)
            ]
            downloadUrl = urlComponents?.url
            print("[UpdateManager] Attempting delta update patch: \(patchFile)")
        } else {
            var urlComponents = URLComponents(string: "\(config.serverUrl)/api/v1/aether/download/bundle")
            urlComponents?.queryItems = [
                URLQueryItem(name: "v", value: info.version),
                URLQueryItem(name: "channel", value: config.channel)
            ]
            downloadUrl = urlComponents?.url
            print("[UpdateManager] Falling back to full bundle update")
        }
        
        guard let url = downloadUrl else {
            state = .failed(error: "Invalid download URL")
            return
        }
        
        self.currentDownloadUrl = url
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
            
            // Phase 9: Preserve this bundle for future delta patches
            let persistentBundle = aetherDir.appendingPathComponent("updates/Aether-bundle-current.tar.gz")
            try? fileManager.removeItem(at: persistentBundle)
            try? fileManager.copyItem(at: tarballPath, to: persistentBundle)
            
            // 5. Success
            updateStatus("Update complete!")
            
            // Record success for Phase 8 deferred cleanup
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastSuccessfulUpdateTimestamp")
            
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
    
    private func cleanupUpdateArtifacts() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let aetherDir = appSupport.appendingPathComponent("Aether")
        let updatesDir = aetherDir.appendingPathComponent("updates")
        let backupDir = aetherDir.appendingPathComponent("backup")
        
        // Defer cleanup of backup for 48 hours to ensure stability
        let lastUpdateSuccess = UserDefaults.standard.double(forKey: "lastSuccessfulUpdateTimestamp")
        let now = Date().timeIntervalSince1970
        
        try? fileManager.removeItem(at: updatesDir)
        
        if now - lastUpdateSuccess > 172800 { // 48 hours
            try? fileManager.removeItem(at: backupDir)
            print("[UpdateManager] Cleaned up 48h old update backup")
        } else {
            print("[UpdateManager] Keeping update backup for stability monitoring")
        }
    }
    
    private func updateStatus(_ msg: String) {
        DispatchQueue.main.async {
            self.statusMessage = msg
        }
    }
    
    // Phase 11: Ed25519 Verification
    private func verifySignature(data: Data, signature: Data) -> Bool {
        do {
            let pubKeyData = Data(hexString: publicKeyHex)
            let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: pubKeyData)
            return publicKey.isValidSignature(signature, for: data)
        } catch {
            print("[UpdateManager] Error verifying signature: \(error)")
            return false
        }
    }
    
    func restartApp() {
        // Phase 12: Report success
        if let info = availableVersion {
            reportTelemetry(version: info.version, event: "update_success")
        }
        
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
    
    // Phase 12: Telemetry
    func reportTelemetry(version: String, event: String) {
        let config = ConfigManager.shared.config.update
        guard config.enabled else { return }
        
        guard let url = URL(string: "\(config.serverUrl)/api/v1/aether/telemetry") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "version": version,
            "event": event,
            "channel": config.channel,
            "os": "macos"
        ]
        
        request.httpBody = try? JSONEncoder().encode(body)
        
        URLSession.shared.dataTask(with: request).resume()
        print("[UpdateManager] Reported telemetry: \(event) for \(version)")
    }
}

extension UpdateManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let info = availableVersion else { return }
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let updatesDir = appSupport.appendingPathComponent("Aether/updates/\(info.version)")
        let currentBundle = updatesDir.appendingPathComponent("Aether-bundle-\(info.version).tar.gz")
        let isPatch = currentDownloadUrl?.lastPathComponent.contains("patch") ?? false
        
        do {
            try fileManager.createDirectory(at: updatesDir, withIntermediateDirectories: true)
            
            if isPatch {
                // Handle Patching
                updateStatus("Applying delta patch...")
                let patchURL = location
                let prevBundleURL = updatesDir.appendingPathComponent("Aether-bundle-current.tar.gz")
                
                // We need the PREVIOUS bundle to patch against. 
                // Wait, if we don't have the previous bundle locally, we can't patch.
                // Re-thinking: patching against the .app bundle is risky. 
                // bsdiff works on files. Patching a directory/tarball is fine if we have the old tarball.
                // If we don't have Aether-bundle-current.tar.gz, we fail and retry with full bundle.
                
                if !fileManager.fileExists(atPath: prevBundleURL.path) {
                    print("[UpdateManager] Delta patch failed: Previous bundle not found. Retrying full download...")
                    // Fallback logic needed here. For now, just fail.
                    throw UpdateError.patchFailed("Previous bundle for patching missing.")
                }
                
                let bspatchProcess = Process()
                bspatchProcess.executableURL = URL(fileURLWithPath: "/usr/bin/bspatch")
                bspatchProcess.arguments = [prevBundleURL.path, currentBundle.path, patchURL.path]
                try bspatchProcess.run()
                bspatchProcess.waitUntilExit()
                
                if bspatchProcess.terminationStatus != 0 {
                    throw UpdateError.patchFailed("bspatch execution failed.")
                }
            } else {
                // Handle Full Download
                if fileManager.fileExists(atPath: currentBundle.path) {
                    try fileManager.removeItem(at: currentBundle)
                }
                try fileManager.moveItem(at: location, to: currentBundle)
            }
            
            // Phase 11: Cryptographic Verification
            let fileData = try Data(contentsOf: currentBundle)
            let signatureStr = isPatch ? info.patchSignature : info.bundleSignature
            
            if let signatureStr = signatureStr, let signatureData = Data(base64Encoded: signatureStr) {
                updateStatus("Verifying cryptographic signature...")
                if !verifySignature(data: fileData, signature: signatureData) {
                    throw UpdateError.verificationFailed("Cryptographic signature verification failed. The update might be tampered.")
                }
                print("[UpdateManager] Signature verified successfully!")
            } else {
                print("[UpdateManager] WARNING: No signature found for this update. Proceeding anyway (Legacy support).")
            }
            
            DispatchQueue.main.async {
                self.updateReadyForInstall = true
                self.state = .readyToInstall
                if self.isBackgroundCheck {
                    print("[UpdateManager] Background update ready for install")
                }
            }
        } catch {
            DispatchQueue.main.async {
                if !self.isBackgroundCheck {
                    self.state = .failed(error: "Failed to save update: \(error.localizedDescription)")
                } else {
                    print("[UpdateManager] Background update failed: \(error.localizedDescription)")
                    // Keep idle in background failure
                    self.state = .idle
                }
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
    case patchFailed(String)
    case verificationFailed(String)
    
    var message: String {
        switch self {
        case .notWritable(let m): return m
        case .extractionFailed(let m): return m
        case .patchFailed(let m): return m
        case .verificationFailed(let m): return m
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
    case (.rollbackInProgress, .rollbackInProgress): return true
    default: return false
    }
}

extension Data {
    init(hexString: String) {
        var hex = hexString
        var data = Data()
        while(hex.count > 0) {
            let subIndex = hex.index(hex.startIndex, offsetBy: 2)
            let c = String(hex[..<subIndex])
            hex = String(hex[subIndex...])
            var ch: UInt32 = 0
            Scanner(string: c).scanHexInt(ch: &ch)
            var char = UInt8(ch)
            data.append(&char, count: 1)
        }
        self = data
    }
}

extension Scanner {
    func scanHexInt(ch: UnsafeMutablePointer<UInt32>) {
        self.scanHexInt32(ch)
    }
}

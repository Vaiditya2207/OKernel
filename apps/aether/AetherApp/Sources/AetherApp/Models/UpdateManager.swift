import Foundation
import Combine

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

class UpdateManager: ObservableObject {
    static let shared = UpdateManager()
    
    @Published var state: UpdateState = .idle
    @Published var availableVersion: AetherVersionInfo?
    @Published var downloadProgress: Double = 0.0
    @Published var statusMessage: String = ""
    
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
    
    private init() {
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
                    // Silent fail if background, but record error if we were explicitly checking
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
    
    // MARK: - Stubs for Phase 4/5
    
    func downloadUpdate() {
        print("[UpdateManager] downloadUpdate() - Stube for Phase 4")
    }
    
    func cancelDownload() {
        print("[UpdateManager] cancelDownload() - Stube for Phase 4")
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

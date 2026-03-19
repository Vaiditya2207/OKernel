import Foundation
import AppKit

// MARK: - Top Level Config
struct AetherConfig: Codable {
    var window: WindowConfig
    var ui: UIConfig
    var font: FontConfig
    var cursor: CursorConfig
    var colors: ColorConfig
    var keys: KeyBindingConfig
    var behavior: BehaviorConfig
    var session: SessionConfig = SessionConfig()
    var terminal: TerminalConfig = TerminalConfig()
    var update: UpdateConfig = UpdateConfig()

    // Default Configuration
    static let `default` = AetherConfig(
        window: WindowConfig(),
        ui: UIConfig(),
        font: FontConfig(),
        cursor: CursorConfig(),
        colors: ColorConfig(),
        keys: KeyBindingConfig(),
        behavior: BehaviorConfig(),
        session: SessionConfig(),
        terminal: TerminalConfig(),
        update: UpdateConfig()
    )

    init(window: WindowConfig, ui: UIConfig, font: FontConfig, cursor: CursorConfig, colors: ColorConfig, keys: KeyBindingConfig, behavior: BehaviorConfig, session: SessionConfig, terminal: TerminalConfig, update: UpdateConfig = UpdateConfig()) {
        self.window = window
        self.ui = ui
        self.font = font
        self.cursor = cursor
        self.colors = colors
        self.keys = keys
        self.behavior = behavior
        self.session = session
        self.terminal = terminal
        self.update = update
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.window = try container.decodeIfPresent(WindowConfig.self, forKey: .window) ?? WindowConfig()
        self.ui = try container.decodeIfPresent(UIConfig.self, forKey: .ui) ?? UIConfig()
        self.font = try container.decodeIfPresent(FontConfig.self, forKey: .font) ?? FontConfig()
        self.cursor = try container.decodeIfPresent(CursorConfig.self, forKey: .cursor) ?? CursorConfig()
        self.colors = try container.decodeIfPresent(ColorConfig.self, forKey: .colors) ?? ColorConfig()
        self.keys = try container.decodeIfPresent(KeyBindingConfig.self, forKey: .keys) ?? KeyBindingConfig()
        self.behavior = try container.decodeIfPresent(BehaviorConfig.self, forKey: .behavior) ?? BehaviorConfig()
        self.session = try container.decodeIfPresent(SessionConfig.self, forKey: .session) ?? SessionConfig()
        self.terminal = try container.decodeIfPresent(TerminalConfig.self, forKey: .terminal) ?? TerminalConfig()
        self.update = try container.decodeIfPresent(UpdateConfig.self, forKey: .update) ?? UpdateConfig()
    }
}

// MARK: - Window Settings
struct WindowConfig: Codable {
    var opacity: Float = 0.95
    var blurType: BlurType = .sidebar
    var titleBar: TitleBarMode = .transparent
    var padding: Padding = Padding(x: 10, y: 10)
    
    enum BlurType: String, Codable {
        case sidebar, header, hud, none
        
        var material: NSVisualEffectView.Material {
            switch self {
            case .sidebar: return .sidebar
            case .header: return .headerView
            case .hud: return .hudWindow
            case .none: return .windowBackground // Corrected from .window
            }
        }
    }
    
    enum TitleBarMode: String, Codable {
        case transparent, native, hidden
    }
    
    struct Padding: Codable {
        var x: Int = 10
        var y: Int = 10
        
        init(x: Int = 10, y: Int = 10) {
            self.x = x
            self.y = y
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.x = try container.decodeIfPresent(Int.self, forKey: .x) ?? 10
            self.y = try container.decodeIfPresent(Int.self, forKey: .y) ?? 10
        }
    }
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.opacity = try container.decodeIfPresent(Float.self, forKey: .opacity) ?? 0.95
        self.blurType = try container.decodeIfPresent(BlurType.self, forKey: .blurType) ?? .sidebar
        self.titleBar = try container.decodeIfPresent(TitleBarMode.self, forKey: .titleBar) ?? .transparent
        self.padding = try container.decodeIfPresent(Padding.self, forKey: .padding) ?? Padding()
    }
}

// MARK: - UI Settings
struct UIConfig: Codable {
    var scrollbar: ScrollbarConfig = ScrollbarConfig()
    var showTooltips: Bool = true
    
    struct ScrollbarConfig: Codable {
        var width: CGFloat = 12
        var padding: VerticalPadding = VerticalPadding(top: 4, bottom: 4)
        var visible: Bool = true
        
        init() {}
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.width = try container.decodeIfPresent(CGFloat.self, forKey: .width) ?? 12
            self.padding = try container.decodeIfPresent(VerticalPadding.self, forKey: .padding) ?? VerticalPadding()
            self.visible = try container.decodeIfPresent(Bool.self, forKey: .visible) ?? true
        }
    }
    
    var scroll: ScrollConfig = ScrollConfig()
    var tabs: TabsConfig = TabsConfig()
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.scrollbar = try container.decodeIfPresent(ScrollbarConfig.self, forKey: .scrollbar) ?? ScrollbarConfig()
        self.showTooltips = try container.decodeIfPresent(Bool.self, forKey: .showTooltips) ?? true
        self.scroll = try container.decodeIfPresent(ScrollConfig.self, forKey: .scroll) ?? ScrollConfig()
        self.tabs = try container.decodeIfPresent(TabsConfig.self, forKey: .tabs) ?? TabsConfig()
    }
    
    enum CodingKeys: String, CodingKey {
        case scrollbar, scroll, tabs
        case showTooltips = "show_tooltips"
    }
    
    struct ScrollConfig: Codable {
        var naturalScrolling: Bool = true
        var speed: Float = 1.0
        
        init() {}
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.naturalScrolling = try container.decodeIfPresent(Bool.self, forKey: .naturalScrolling) ?? true
            self.speed = try container.decodeIfPresent(Float.self, forKey: .speed) ?? 1.0
        }
    }
    
    struct TabsConfig: Codable {
        var verticalPadding: CGFloat = 2
        var horizontalPadding: CGFloat = 10
        var cornerRadius: CGFloat = 6
        var titleStyle: TitleStyle = .smart
        
        init() {}
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.verticalPadding = try container.decodeIfPresent(CGFloat.self, forKey: .verticalPadding) ?? 2
            self.horizontalPadding = try container.decodeIfPresent(CGFloat.self, forKey: .horizontalPadding) ?? 10
            self.cornerRadius = try container.decodeIfPresent(CGFloat.self, forKey: .cornerRadius) ?? 6
            self.titleStyle = try container.decodeIfPresent(TitleStyle.self, forKey: .titleStyle) ?? .smart
        }
    }
    
    enum TitleStyle: String, Codable {
        case smart, path, process
    }
    
    struct VerticalPadding: Codable {
        var top: CGFloat = 4
        var bottom: CGFloat = 4
        
        init(top: CGFloat = 4, bottom: CGFloat = 4) {
            self.top = top
            self.bottom = bottom
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.top = try container.decodeIfPresent(CGFloat.self, forKey: .top) ?? 4
            self.bottom = try container.decodeIfPresent(CGFloat.self, forKey: .bottom) ?? 4
        }
    }
}

// MARK: - Font Settings
struct FontConfig: Codable {
    var family: String = "JetBrains Mono"
    var size: Float = 14.0
    var lineHeight: Float = 1.2
    var weight: FontWeight = .regular
    var ligatures: Bool = true
    
    enum FontWeight: String, Codable {
        case regular, bold, light, thin, medium, semibold, heavy, black
    }
    
    enum CodingKeys: String, CodingKey {
        case family, size, weight, ligatures
        case lineHeight
    }
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.family = try container.decodeIfPresent(String.self, forKey: .family) ?? "JetBrains Mono"
        self.size = try container.decodeIfPresent(Float.self, forKey: .size) ?? 14.0
        self.lineHeight = try container.decodeIfPresent(Float.self, forKey: .lineHeight) ?? 1.2
        self.weight = try container.decodeIfPresent(FontWeight.self, forKey: .weight) ?? .regular
        self.ligatures = try container.decodeIfPresent(Bool.self, forKey: .ligatures) ?? true
    }
}

// MARK: - Cursor Settings
struct CursorConfig: Codable {
    var style: CursorStyle = .block
    var blink: Bool = true
    var smartBlink: Bool = true
    var blinkRate: Float = 0.8
    var blinkCurve: BlinkCurve = .ease
    
    enum CursorStyle: String, Codable {
        case block, beam, underline
    }
    
    enum BlinkCurve: String, Codable {
        case ease, linear
    }
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.style = try container.decodeIfPresent(CursorStyle.self, forKey: .style) ?? .block
        self.blink = try container.decodeIfPresent(Bool.self, forKey: .blink) ?? true
        self.smartBlink = try container.decodeIfPresent(Bool.self, forKey: .smartBlink) ?? true
        self.blinkRate = try container.decodeIfPresent(Float.self, forKey: .blinkRate) ?? 0.8
        self.blinkCurve = try container.decodeIfPresent(BlinkCurve.self, forKey: .blinkCurve) ?? .ease
    }
}

// MARK: - Color Settings
struct ColorConfig: Codable {
    var scheme: String = "Dracula"
    var background: String? = nil // Override
    var foreground: String? = nil // Override
    var selection: String? = nil
    var palette: [String]? = nil // Custom palette override
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.scheme = try container.decodeIfPresent(String.self, forKey: .scheme) ?? "Dracula"
        self.background = try container.decodeIfPresent(String.self, forKey: .background)
        self.foreground = try container.decodeIfPresent(String.self, forKey: .foreground)
        self.selection = try container.decodeIfPresent(String.self, forKey: .selection)
        self.palette = try container.decodeIfPresent([String].self, forKey: .palette)
    }
    
    // Helper to get effective theme
    func resolveTheme() -> Theme {
        // Start with base scheme
        var theme = Theme.named(scheme) ?? Theme.dracula
        
        // Apply overrides
        if let bg = background { theme.background = bg }
        if let fg = foreground { theme.foreground = fg }
        if let sel = selection { theme.selection = sel }
        if let pal = palette, pal.count == 16 { theme.palette = pal }
        
        return theme
    }
}

struct Theme: Codable {
    var name: String
    var background: String
    var foreground: String
    var selection: String
    var palette: [String]
    
    static let dracula = Theme(
        name: "Dracula",
        background: "#00000000",
        foreground: "#F8F8F2",
        selection: "#44475A",
        palette: [
            "#21222C", "#FF5555", "#50FA7B", "#F1FA8C",
            "#BD93F9", "#FF79C6", "#8BE9FD", "#F8F8F2",
            "#6272A4", "#FF6E6E", "#69FF94", "#FFFFC7",
            "#D6ACFF", "#FF92DF", "#A4FFFF", "#FFFFFF"
        ]
    )
    
    static let solarizedDark = Theme(
        name: "Solarized Dark",
        background: "#00000000",
        foreground: "#839496",
        selection: "#073642",
        palette: [
            "#073642", "#DC322F", "#859900", "#B58900",
            "#268BD2", "#D33682", "#2AA198", "#EEE8D5",
            "#002B36", "#CB4B16", "#586E75", "#657B83",
            "#839496", "#6C71C4", "#93A1A1", "#FDF6E3"
        ]
    )
    
    static let oneDark = Theme(
        name: "OneDark",
        background: "#00000000",
        foreground: "#ABB2BF",
        selection: "#3E4452",
        palette: [
            "#282C34", "#E06C75", "#98C379", "#E5C07B",
            "#61AFEF", "#C678DD", "#56B6C2", "#ABB2BF",
            "#5C6370", "#E06C75", "#98C379", "#E5C07B",
            "#61AFEF", "#C678DD", "#56B6C2", "#FFFFFF"
        ]
    )
    
    static let catppuccinMocha = Theme(
        name: "Catppuccin Mocha",
        background: "#1E1E2E",
        foreground: "#CDD6F4",
        selection: "#45475A",
        palette: [
            "#45475A", "#F38BA8", "#A6E3A1", "#F9E2AF",
            "#89B4FA", "#F5C2E7", "#94E2D5", "#BAC2DE",
            "#585B70", "#F38BA8", "#A6E3A1", "#F9E2AF",
            "#89B4FA", "#F5C2E7", "#94E2D5", "#A6ADC8"
        ]
    )
    
    static func named(_ name: String) -> Theme? {
        let n = name.lowercased()
        if n == "dracula" { return .dracula }
        if n == "solarized dark" { return .solarizedDark }
        if n == "onedark" { return .oneDark }
        if n.contains("catppuccin") || n.contains("mocha") { return .catppuccinMocha }
        return nil
    }
}

// MARK: - Key Bindings
struct KeyBindingConfig: Codable {
    var bindings: [String: String] = [
        "cmd+c": "copy",
        "cmd+v": "paste",
        "cmd+t": "new_tab",
        "cmd+w": "close_tab",
        "cmd+n": "new_window",
        
        // Multi-Window
        "cmd+d": "split_horizontal",
        "cmd+shift+d": "split_vertical",
        "cmd+shift+w": "close_pane",
        
        // Focus (Leader Key)
        "cmd+x": "enter_window_mode",
        "left": "focus_left",
        "right": "focus_right",
        "up": "focus_up",
        "down": "focus_down"
    ]
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.bindings = try container.decodeIfPresent([String: String].self, forKey: .bindings) ?? [
            "cmd+c": "copy",
            "cmd+v": "paste",
            "cmd+t": "new_tab",
            "cmd+w": "close_tab",
            "cmd+n": "new_window",
            "cmd+d": "split_horizontal",
            "cmd+shift+d": "split_vertical",
            "cmd+shift+w": "close_pane",
            "cmd+x": "enter_window_mode",
            "left": "focus_left",
            "right": "focus_right",
            "up": "focus_up",
            "down": "focus_down"
        ]
    }
}

// MARK: - Behavior Settings
struct BehaviorConfig: Codable {
    var ctrlcSendsSigint: Bool = true
    var keyboardSelection: Bool = true
    
    enum CodingKeys: String, CodingKey {
        case ctrlcSendsSigint = "ctrlc_sends_sigint"
        case keyboardSelection = "keyboard_selection"
    }
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.ctrlcSendsSigint = try container.decodeIfPresent(Bool.self, forKey: .ctrlcSendsSigint) ?? true
        self.keyboardSelection = try container.decodeIfPresent(Bool.self, forKey: .keyboardSelection) ?? true
    }
}

// MARK: - Session Settings
struct SessionConfig: Codable {
    var restoreStrategy: RestoreStrategy = .ask
    var restoreShortcut: String = "cmd+shift+r"
    
    enum RestoreStrategy: String, Codable {
        case ask, always, never
    }
    
    enum CodingKeys: String, CodingKey {
        case restoreStrategy = "restore_strategy"
        case restoreShortcut = "restore_shortcut"
    }
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.restoreStrategy = try container.decodeIfPresent(RestoreStrategy.self, forKey: .restoreStrategy) ?? .ask
        self.restoreShortcut = try container.decodeIfPresent(String.self, forKey: .restoreShortcut) ?? "cmd+shift+r"
    }
}

// MARK: - Terminal Settings
struct TerminalConfig: Codable {
    var scrollbackLimit: Int = 50000
    
    enum CodingKeys: String, CodingKey {
        case scrollbackLimit = "scrollback_limit"
    }
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.scrollbackLimit = try container.decodeIfPresent(Int.self, forKey: .scrollbackLimit) ?? 50000
    }
}

// MARK: - Update Settings
struct UpdateConfig: Codable {
    var enabled: Bool = true
    var checkInterval: Int = 3600
    var serverUrl: String = "https://api.hackmist.tech"
    var channel: String = "stable"

    enum CodingKeys: String, CodingKey {
        case enabled
        case checkInterval = "check_interval"
        case serverUrl = "server_url"
        case channel
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        let interval = try container.decodeIfPresent(Int.self, forKey: .checkInterval) ?? 3600
        self.checkInterval = max(300, interval)
        self.serverUrl = try container.decodeIfPresent(String.self, forKey: .serverUrl) ?? "https://api.hackmist.tech"
        self.channel = try container.decodeIfPresent(String.self, forKey: .channel) ?? "stable"
    }
}

// MARK: - Config Manager
class ConfigManager: ObservableObject {
    static let shared = ConfigManager()
    
    @Published var config: AetherConfig
    @Published var configError: String? = nil
    
    private init() {
        self.config = AetherConfig.default
        loadConfig()
    }
    
    // Priority:
    // 1. ~/.config/aether/config.json
    // 2. ~/.config/aether/config.toml
    // 3. ~/.config/aether/aether.json
    // 4. ~/.config/aether/aether.toml
    
    func loadConfig() {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let configDir = home.appendingPathComponent(".config/aether")
        
        // Ensure directory exists
        try? fileManager.createDirectory(at: configDir, withIntermediateDirectories: true)
        
        let paths: [URL] = [
            configDir.appendingPathComponent("config.json"),
            configDir.appendingPathComponent("config.toml"),
            configDir.appendingPathComponent("aether.json"),
            configDir.appendingPathComponent("aether.toml")
        ]
        
        var configExists = false
        for path in paths {
            if fileManager.fileExists(atPath: path.path) {
                configExists = true
                if path.pathExtension == "json" {
                    do {
                        let data = try Data(contentsOf: path)
                        let decoder = JSONDecoder()
                        self.config = try decoder.decode(AetherConfig.self, from: data)
                        print("ConfigManager: Loaded JSON \(path.lastPathComponent)")
                        return
                    } catch {
                        print("ConfigManager: Failed to parse JSON \(path.lastPathComponent): \(error)")
                        DispatchQueue.main.async { self.configError = "Syntax Error in \(path.lastPathComponent). Using defaults." }
                        return
                    }
                } else if path.pathExtension == "toml" {
                     do {
                        let content = try String(contentsOf: path, encoding: .utf8)
                        let dict = SimpleTOMLParser.parse(toml: content)
                        if let mappedConfig = mapTomlToConfig(dict) {
                            self.config = mappedConfig
                            print("ConfigManager: Loaded TOML \(path.lastPathComponent)")
                            return
                        }
                    } catch {
                        print("ConfigManager: Failed to parse TOML \(path.lastPathComponent): \(error)")
                        DispatchQueue.main.async { self.configError = "Syntax Error in \(path.lastPathComponent). Using defaults." }
                        return
                    }
                }
            }
        }
        
        // Fallback
        print("ConfigManager: No config found. Using defaults.")
        if !configExists {
            saveConfig()
        }
    }
    
    private func mapTomlToConfig(_ doc: [String: Any]) -> AetherConfig? {
        var cfg = AetherConfig.default
        
        // [window]
        if let win = doc["window"] as? [String: Any] {
            if let opacity = win["opacity"] as? Double { cfg.window.opacity = Float(opacity) }
            if let dec = win["decorations"] as? String {
                cfg.window.titleBar = (dec == "transparent" || dec == "buttonless") ? .transparent : .native
            }
            
            // Map flat padding_x/y to nested object
            let px = (win["padding_x"] as? Int) ?? cfg.window.padding.x
            let py = (win["padding_y"] as? Int) ?? cfg.window.padding.y
            cfg.window.padding = WindowConfig.Padding(x: px, y: py)
        }
        
        // [ui.scroll] - Assuming structure might be flattened or nested differently in TOML
        // Checking for [ui] or direct keys if minimal TOML parser is used
        // [ui.scroll] & [ui.tabs]
        if let ui = doc["ui"] as? [String: Any] {
            if let st = ui["show_tooltips"] as? Bool { cfg.ui.showTooltips = st }
            if let scroll = ui["scroll"] as? [String: Any] {
                 if let spd = scroll["speed"] as? Double { cfg.ui.scroll.speed = Float(spd) }
            }
            if let tabs = ui["tabs"] as? [String: Any] {
                 if let v = tabs["vertical_padding"] as? Double { cfg.ui.tabs.verticalPadding = CGFloat(v) }
                 if let h = tabs["horizontal_padding"] as? Double { cfg.ui.tabs.horizontalPadding = CGFloat(h) }
                 if let r = tabs["corner_radius"] as? Double { cfg.ui.tabs.cornerRadius = CGFloat(r) }
                 if let s = tabs["title_style"] as? String, let style = UIConfig.TitleStyle(rawValue: s) {
                     cfg.ui.tabs.titleStyle = style
                 }
            }
        }
        
        // [font]
        if let font = doc["font"] as? [String: Any] {
            if let family = font["family"] as? String { cfg.font.family = family }
            if let size = font["size"] as? Double { cfg.font.size = Float(size) }
            if let ligs = font["ligatures"] as? Bool { cfg.font.ligatures = ligs }
        }
        
        // [theme] -> [colors]
        if let theme = doc["theme"] as? [String: Any] {
            if let name = theme["name"] as? String {
                // Map common naming differences if needed
                if name.lowercased().contains("catppuccin") {
                    cfg.colors.scheme = "Dracula" // Fallback map since we lack Catppuccin defs, or just pass string
                    // Ideally we'd map "catppuccin-mocha" -> some theme. 
                    // For now, let's keep the name so it tries to load or falls back to valid theme.
                    cfg.colors.scheme = name
                    // Actually, if we leave it "catppuccin-mocha", resolveTheme will default to Dracula unless we add it.
                    // Let's explicitly check if we want to add Catppuccin later.
                } else {
                    cfg.colors.scheme = name
                }
            }
        }
        
        // [cursor]
        if let cursor = doc["cursor"] as? [String: Any] {
            if let sb = cursor["smartBlink"] as? Bool { cfg.cursor.smartBlink = sb }
            if let blink = cursor["blink"] as? Bool { cfg.cursor.blink = blink }
        }
        
        // [behavior]
        if let behavior = doc["behavior"] as? [String: Any] {
            if let sigint = behavior["ctrlc_sends_sigint"] as? Bool { cfg.behavior.ctrlcSendsSigint = sigint }
            if let ks = behavior["keyboard_selection"] as? Bool { cfg.behavior.keyboardSelection = ks }
        }
        
        // [session]
        if let session = doc["session"] as? [String: Any] {
            if let s = session["restore_strategy"] as? String, let strategy = SessionConfig.RestoreStrategy(rawValue: s) {
                cfg.session.restoreStrategy = strategy
            }
            if let shortcut = session["restore_shortcut"] as? String {
                cfg.session.restoreShortcut = shortcut
            }
        }
        
        // [terminal]
        if let terminal = doc["terminal"] as? [String: Any] {
            if let limit = terminal["scrollback_limit"] as? Int {
                cfg.terminal.scrollbackLimit = limit
            }
        }

        // [update]
        if let update = doc["update"] as? [String: Any] {
            if let enabled = update["enabled"] as? Bool { cfg.update.enabled = enabled }
            if let interval = update["check_interval"] as? Int { cfg.update.checkInterval = max(300, interval) }
            if let serverUrl = update["server_url"] as? String { cfg.update.serverUrl = serverUrl }
            if let channel = update["channel"] as? String { cfg.update.channel = channel }
        }

        return cfg
    }
    
    func saveConfig() {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let configDir = home.appendingPathComponent(".config/aether")
        let configPath = configDir.appendingPathComponent("config.json")
        
        do {
            try fileManager.createDirectory(at: configDir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(config)
            try data.write(to: configPath)
        } catch {
            print("Failed to save config: \(error)")
        }
    }
    
    // Helper: Hex String to UInt32 (0xAARRGGBB)
    func parseColor(_ hex: String) -> UInt32 {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        if hexSanitized.count == 6 {
            return UInt32(0xFF000000) | UInt32(rgb)
        } else if hexSanitized.count == 8 {
            return UInt32(rgb)
        }
        return 0xFFFFFFFF
    }
}

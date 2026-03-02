import SwiftUI
import Combine
import AppKit

// MARK: - Data Model

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    var content: String
    var isStreaming: Bool = false
    
    enum Role {
        case user
        case keith
        case tool // command output
    }
    
    // Strip hidden exec tags from display
    var displayContent: String {
        content.replacingOccurrences(
            of: "<!--EXEC:.*?-->",
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - ViewModel

class KeithChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isTyping: Bool = false
    
    // Reference to terminal session — set by the view
    weak var terminalSession: TerminalSession?
    
    var conversationContext: String {
        messages.suffix(10).map { msg in
            switch msg.role {
            case .user: return "User: \(msg.content)"
            case .keith: return "Keith: \(msg.displayContent)"
            case .tool: return "Command Output: \(msg.content)"
            }
        }.joined(separator: "\n")
    }
    
    func sendMessage(context: String = "") {
        let query = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        
        messages.append(ChatMessage(role: .user, content: query))
        inputText = ""
        isTyping = true
        
        let keithIdx = messages.count
        messages.append(ChatMessage(role: .keith, content: "", isStreaming: true))
        
        let fullContext = "Terminal:\n\(context)\n\nChat:\n\(conversationContext)"
        
        SyscoreClient.shared.streamChat(
            message: query,
            context: fullContext,
            onToken: { [weak self] token in
                guard let self = self, keithIdx < self.messages.count else { return }
                self.messages[keithIdx].content += token
            },
            onComplete: { [weak self] in
                guard let self = self, keithIdx < self.messages.count else { return }
                self.messages[keithIdx].isStreaming = false
                self.isTyping = false
                self.processAgentActions(messageIdx: keithIdx)
            },
            onError: { [weak self] error in
                guard let self = self, keithIdx < self.messages.count else { return }
                if self.messages[keithIdx].content.isEmpty {
                    self.messages[keithIdx].content = "Connection issue: \(error)"
                }
                self.messages[keithIdx].isStreaming = false
                self.isTyping = false
            }
        )
    }
    
    // MARK: - Agentic: Detect <!--EXEC:command--> and run in terminal
    
    private func processAgentActions(messageIdx: Int) {
        guard messageIdx < messages.count else { return }
        let content = messages[messageIdx].content
        
        guard let regex = try? NSRegularExpression(pattern: "<!--EXEC:(.*?)-->", options: .dotMatchesLineSeparators) else { return }
        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, range: range)
        
        guard let match = matches.first,
              let cmdRange = Range(match.range(at: 1), in: content) else { return }
        
        let command = String(content[cmdRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }
        
        // Run the command in the actual terminal
        runInTerminal(command)
    }
    
    func runInTerminal(_ command: String) {
        guard let session = terminalSession else { return }
        
        // Show what we're running
        messages.append(ChatMessage(role: .tool, content: "▸ \(command)"))
        let toolIdx = messages.count - 1
        
        // Inject command into the real terminal
        session.writeInput(command + "\r")
        isTyping = true
        
        // Wait for the command to finish, then read output
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self = self else { return }
            let output = session.getRecentContext(lines: 20)
            self.messages[toolIdx].content = "▸ \(command)\n\(output)"
            
            // Feed result back to Keith
            let keithIdx = self.messages.count
            self.messages.append(ChatMessage(role: .keith, content: "", isStreaming: true))
            
            let followUp = "I ran `\(command)` in the terminal. Here's the output:\n\(output)\n\nAnalyze this and respond concisely."
            let ctx = "Terminal:\n\(output)\nChat:\n\(self.conversationContext)"
            
            SyscoreClient.shared.streamChat(
                message: followUp,
                context: ctx,
                onToken: { [weak self] token in
                    guard let self = self, keithIdx < self.messages.count else { return }
                    self.messages[keithIdx].content += token
                },
                onComplete: { [weak self] in
                    guard let self = self, keithIdx < self.messages.count else { return }
                    self.messages[keithIdx].isStreaming = false
                    self.isTyping = false
                },
                onError: { [weak self] error in
                    guard let self = self, keithIdx < self.messages.count else { return }
                    self.messages[keithIdx].content += " (error: \(error))"
                    self.messages[keithIdx].isStreaming = false
                    self.isTyping = false
                }
            )
        }
    }
    
    func runCodeBlock(_ code: String) {
        runInTerminal(code.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

// MARK: - Color Helper

extension Color {
    init(keithHex: String) {
        let hex = keithHex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        if hex.count == 6 {
            self.init(red: Double((rgb >> 16) & 0xFF) / 255, green: Double((rgb >> 8) & 0xFF) / 255, blue: Double(rgb & 0xFF) / 255)
        } else if hex.count == 8 {
            self.init(red: Double((rgb >> 16) & 0xFF) / 255, green: Double((rgb >> 8) & 0xFF) / 255, blue: Double(rgb & 0xFF) / 255, opacity: Double((rgb >> 24) & 0xFF) / 255)
        } else {
            self.init(white: 0)
        }
    }
}

// MARK: - Sidebar View

struct KeithChatView: View {
    @StateObject private var viewModel = KeithChatViewModel()
    @Binding var isPresented: Bool
    var terminalSession: TerminalSession
    @Binding var sidebarWidth: CGFloat
    
    @FocusState private var isInputFocused: Bool
    @State private var isDragging = false
    
    // Theme colors
    var theme: Theme { ConfigManager.shared.config.colors.resolveTheme() }
    var font: String { ConfigManager.shared.config.font.family }
    
    var bg: Color {
        let h = theme.background
        return (h == "#00000000") ? Color(keithHex: theme.palette[0]) : Color(keithHex: h)
    }
    var fg: Color { Color(keithHex: theme.foreground) }
    var sel: Color { Color(keithHex: theme.selection) }
    var green: Color { theme.palette.count > 2 ? Color(keithHex: theme.palette[2]) : .green }
    var yellow: Color { theme.palette.count > 3 ? Color(keithHex: theme.palette[3]) : .yellow }
    var blue: Color { theme.palette.count > 4 ? Color(keithHex: theme.palette[4]) : .blue }
    var purple: Color { theme.palette.count > 5 ? Color(keithHex: theme.palette[5]) : .purple }
    var cyan: Color { theme.palette.count > 6 ? Color(keithHex: theme.palette[6]) : .cyan }
    var dim: Color { fg.opacity(0.4) }
    
    var body: some View {
        HStack(spacing: 0) {
            // ─── Drag Handle ───
            Rectangle()
                .fill(isDragging ? green.opacity(0.6) : Color.clear)
                .frame(width: 3)
                .contentShape(Rectangle().inset(by: -4))
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            isDragging = true
                            let screen = NSScreen.main?.frame.width ?? 1440
                            let newW = sidebarWidth - value.translation.width
                            sidebarWidth = min(max(newW, screen * 0.1), screen * 0.7)
                        }
                        .onEnded { _ in isDragging = false }
                )
                .onHover { h in h ? NSCursor.resizeLeftRight.push() : NSCursor.pop() }
            
            // ─── Main Panel ───
            VStack(spacing: 0) {
                header
                Divider().background(fg.opacity(0.06))
                messageList
                Divider().background(fg.opacity(0.06))
                inputBar
            }
            .background(bg)
        }
        .onAppear {
            viewModel.terminalSession = terminalSession
            isInputFocused = true
        }
    }
    
    // MARK: Header
    
    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(green.opacity(0.15))
                    .frame(width: 26, height: 26)
                Text("K")
                    .font(.custom(font, size: 12).bold())
                    .foregroundColor(green)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                Text("Keith")
                    .font(.custom(font, size: 12).bold())
                    .foregroundColor(fg)
                if viewModel.isTyping {
                    Text("thinking...")
                        .font(.custom(font, size: 9))
                        .foregroundColor(yellow)
                }
            }
            
            Spacer()
            
            Button(action: { viewModel.messages.removeAll() }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(fg.opacity(0.35))
            }
            .buttonStyle(PlainButtonStyle())
            .help("New conversation")
            
            Button(action: { withAnimation(.easeOut(duration: 0.15)) { isPresented = false } }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(fg.opacity(0.35))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
    
    // MARK: Message List
    
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    if viewModel.messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(viewModel.messages) { msg in
                            messageView(msg)
                        }
                    }
                }
            }
            .onChange(of: viewModel.messages.count) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.messages.last?.content) { _ in
                if viewModel.isTyping {
                    proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                }
            }
        }
    }
    
    // MARK: Input Bar
    
    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Ask Keith...", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.custom(font, size: 13))
                .foregroundColor(fg)
                .focused($isInputFocused)
                .lineLimit(1...5)
                .onSubmit { submit() }
            
            Button(action: submit) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(canSend ? .black : fg.opacity(0.15))
                    .frame(width: 24, height: 24)
                    .background(canSend ? green : fg.opacity(0.08))
                    .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!canSend)
        }
        .padding(12)
    }
    
    private var canSend: Bool {
        !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isTyping
    }
    
    // MARK: Empty State
    
    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 30)
            
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(green.opacity(0.08))
                    .frame(width: 44, height: 44)
                Text("K")
                    .font(.custom(font, size: 20).bold())
                    .foregroundColor(green)
            }
            
            Text("Keith")
                .font(.custom(font, size: 15).bold())
                .foregroundColor(fg)
            
            Text("I run commands in your terminal\nand help you debug.")
                .font(.custom(font, size: 11))
                .foregroundColor(dim)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            
            VStack(spacing: 6) {
                quickBtn("What's using port 3000?")
                quickBtn("Find this project's structure")
                quickBtn("Check disk usage")
            }
            .padding(.top, 4)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }
    
    private func quickBtn(_ text: String) -> some View {
        Button(action: {
            viewModel.inputText = text
            submit()
        }) {
            HStack {
                Text(text)
                    .font(.custom(font, size: 11))
                    .foregroundColor(fg.opacity(0.5))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 8))
                    .foregroundColor(fg.opacity(0.2))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(fg.opacity(0.04))
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func submit() {
        let context = terminalSession.getRecentContext(lines: 40)
        viewModel.sendMessage(context: context)
        isInputFocused = true
    }
    
    // MARK: Message View
    
    @ViewBuilder
    private func messageView(_ msg: ChatMessage) -> some View {
        switch msg.role {
        case .user:
            userBubble(msg)
        case .keith:
            keithBubble(msg)
        case .tool:
            toolBlock(msg)
        }
    }
    
    private func userBubble(_ msg: ChatMessage) -> some View {
        HStack {
            Spacer()
            Text(msg.content)
                .font(.custom(font, size: 13))
                .foregroundColor(fg)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(sel.opacity(0.6))
                .cornerRadius(8)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .id(msg.id)
    }
    
    private func keithBubble(_ msg: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if msg.isStreaming && msg.displayContent.isEmpty {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.7)
                    Text("Thinking...")
                        .font(.custom(font, size: 11))
                        .foregroundColor(dim)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            } else if !msg.displayContent.isEmpty {
                MarkdownView(
                    text: msg.displayContent,
                    fontName: font,
                    fg: fg, sel: sel, green: green, blue: blue, dim: dim,
                    viewModel: viewModel
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
        .id(msg.id)
    }
    
    private func toolBlock(_ msg: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(msg.content)
                    .font(.custom(font, size: 11))
                    .foregroundColor(green.opacity(0.8))
                    .padding(10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(sel.opacity(0.35))
        .cornerRadius(6)
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .id(msg.id)
    }
}

// MARK: - Markdown View

struct MarkdownView: View {
    let text: String
    let fontName: String
    let fg: Color
    let sel: Color
    let green: Color
    let blue: Color
    let dim: Color
    @ObservedObject var viewModel: KeithChatViewModel
    
    enum Block {
        case text(String)
        case code(String, String) // lang, code
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .text(let t):
                    renderText(t)
                case .code(let lang, let code):
                    codeBlock(lang, code)
                }
            }
        }
    }
    
    private var blocks: [Block] {
        var result: [Block] = []
        var rest = text
        
        while let s = rest.range(of: "```") {
            let before = String(rest[rest.startIndex..<s.lowerBound])
            if !before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.append(.text(before))
            }
            rest = String(rest[s.upperBound...])
            
            if let e = rest.range(of: "```") {
                let inner = String(rest[rest.startIndex..<e.lowerBound])
                rest = String(rest[e.upperBound...])
                let lines = inner.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
                let first = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let isLang = !first.isEmpty && first.count < 15 && !first.contains(" ")
                let lang = isLang ? first : ""
                let code = isLang && lines.count > 1
                    ? String(lines[1]).trimmingCharacters(in: .newlines)
                    : inner.trimmingCharacters(in: .newlines)
                result.append(.code(lang, code))
            } else {
                // Unclosed (streaming) — show as code
                result.append(.code("", rest.trimmingCharacters(in: .newlines)))
                rest = ""
            }
        }
        
        if !rest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.append(.text(rest))
        }
        if result.isEmpty && !text.isEmpty {
            result.append(.text(text))
        }
        return result
    }
    
    @ViewBuilder
    private func renderText(_ str: String) -> some View {
        let lines = str.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.isEmpty {
                Spacer().frame(height: 3)
            } else if t.hasPrefix("- ") || t.hasPrefix("* ") {
                HStack(alignment: .top, spacing: 6) {
                    Text("•")
                        .font(.custom(fontName, size: 12))
                        .foregroundColor(dim)
                    Text(styledText(String(t.dropFirst(2))))
                        .font(.custom(fontName, size: 13))
                        .foregroundColor(fg)
                        .textSelection(.enabled)
                }
                .padding(.leading, 6)
            } else {
                Text(styledText(t))
                    .font(.custom(fontName, size: 13))
                    .foregroundColor(fg)
                    .textSelection(.enabled)
            }
        }
    }
    
    private func styledText(_ str: String) -> AttributedString {
        var result = AttributedString()
        var rest = str[str.startIndex...]
        
        while !rest.isEmpty {
            // Inline code `...`
            if rest.first == "`" {
                let after = rest.index(after: rest.startIndex)
                if after < rest.endIndex, let end = rest[after...].firstIndex(of: "`") {
                    let code = String(rest[after..<end])
                    var a = AttributedString(" \(code) ")
                    a.font = .custom(fontName, size: 12)
                    a.foregroundColor = green
                    a.backgroundColor = sel.opacity(0.5)
                    result += a
                    rest = rest[rest.index(after: end)...]
                    continue
                }
            }
            // Bold **...**
            if rest.hasPrefix("**") {
                let after = rest.index(rest.startIndex, offsetBy: 2)
                if after < rest.endIndex, let end = rest[after...].range(of: "**") {
                    let bold = String(rest[after..<end.lowerBound])
                    var a = AttributedString(bold)
                    a.font = .custom(fontName, size: 13).bold()
                    result += a
                    rest = rest[end.upperBound...]
                    continue
                }
            }
            // Italic *...*  (not **)
            if rest.first == "*" && !rest.hasPrefix("**") {
                let after = rest.index(after: rest.startIndex)
                if after < rest.endIndex && rest[after] != " " {
                    if let end = rest[after...].firstIndex(of: "*") {
                        let text = String(rest[after..<end])
                        var a = AttributedString(text)
                        a.font = .custom(fontName, size: 13).italic()
                        a.foregroundColor = fg.opacity(0.8)
                        result += a
                        rest = rest[rest.index(after: end)...]
                        continue
                    }
                }
            }
            // Normal char
            var a = AttributedString(String(rest.first!))
            a.font = .custom(fontName, size: 13)
            result += a
            rest = rest[rest.index(after: rest.startIndex)...]
        }
        return result
    }
    
    @ViewBuilder
    private func codeBlock(_ lang: String, _ code: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                if !lang.isEmpty {
                    Text(lang)
                        .font(.custom(fontName, size: 9))
                        .foregroundColor(dim)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(fg.opacity(0.05))
                        .cornerRadius(3)
                }
                Spacer()
                
                // Run in terminal button
                if looksRunnable(code) {
                    Button(action: { viewModel.runCodeBlock(code) }) {
                        HStack(spacing: 3) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 7))
                            Text("Run")
                                .font(.custom(fontName, size: 9))
                        }
                        .foregroundColor(green)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(green.opacity(0.1))
                        .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 7))
                        Text("Copy")
                            .font(.custom(fontName, size: 9))
                    }
                    .foregroundColor(fg.opacity(0.35))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(fg.opacity(0.05))
                    .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.custom(fontName, size: 12))
                    .foregroundColor(green)
                    .textSelection(.enabled)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
            }
        }
        .background(sel.opacity(0.4))
        .cornerRadius(6)
        .padding(.vertical, 3)
    }
    
    private func looksRunnable(_ code: String) -> Bool {
        let t = code.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.split(separator: "\n").count <= 3 && !t.contains("func ") && !t.contains("def ") && !t.contains("class ")
    }
}

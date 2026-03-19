import Metal
import MetalKit
import simd
import CAether
import AppKit
import QuartzCore
import Darwin

class TerminalRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipelineState: MTLRenderPipelineState
    var fontAtlas: FontAtlas
    let scrollState: TerminalScrollState
    
    // Cursor Override for Visual Selection (e.g. Shift+Arrow)
    public var cursorOverride: (row: UInt32, col: UInt32)?
    
    var isActive: Bool = true {
        didSet {
            // Force redraw on focus change
            forceNextFrame = true
        }
    }
    
    private var lastInputTime: TimeInterval = 0
    
    private var instanceBuffer: MTLBuffer?
    private var viewportSize: SIMD2<Float> = .zero
    private var scaleFactor: Float = 2.0  // Retina: drawable pixels / view points

    // private let lock = NSLock() // Removed in favor of session.lock
    
    // Terminal state (accessed via session)
    weak var session: TerminalSession?
    
    var terminal: OpaquePointer? {
        session?.terminal
    }
    
    var rows: Int = 24
    var cols: Int = 80
    
    init(metalView: MTKView, session: TerminalSession) throws {
        self.session = session
        self.scrollState = session.scrollState
        guard let device = metalView.device else {
            throw NSError(domain: "AetherApp", code: 2, userInfo: [NSLocalizedDescriptionKey: "Metal view has no device"])
        }
        self.device = device
        
        guard let queue = device.makeCommandQueue() else {
             throw NSError(domain: "AetherApp", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create command queue"])
        }
        self.commandQueue = queue
        
        // Load shaders - using robust bundle finder
        let library: MTLLibrary
        let resourceBundle = Bundle.aether
        if let metalURL = resourceBundle.url(forResource: "Shaders", withExtension: "metal"),
           let shaderSource = try? String(contentsOf: metalURL, encoding: .utf8) {
            do {
                library = try device.makeLibrary(source: shaderSource, options: nil)
            } catch {
                throw NSError(domain: "AetherApp", code: 4, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to compile Metal shaders: \(error.localizedDescription)"
                ])
            }
        } else {
            throw NSError(domain: "AetherApp", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Failed to find Shaders.metal in Aether bundle (\(resourceBundle.bundlePath))"
            ])
        }
        
        let vertexFunction = library.makeFunction(name: "vertex_main")
        let fragmentFunction = library.makeFunction(name: "fragment_main")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        
        // Enable alpha blending
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        // Initialize FontAtlas with proper scale
        let scale = metalView.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        let fontConfig = ConfigManager.shared.config.font
        let family = fontConfig.family
        self.fontAtlas = try FontAtlas(device: device, fontName: family, fontSize: CGFloat(fontConfig.size), scale: scale)
        self.scaleFactor = Float(scale)
        
        super.init()
        
        // Apply initial theme from config
        applyTheme(ConfigManager.shared.config.colors.resolveTheme())
        
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleFontLoaded), name: NSNotification.Name("AetherFontLoaded"), object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleFontLoaded() {
        session?.lock.lock()
        defer { session?.lock.unlock() }
        
        do {
            let fontConfig = ConfigManager.shared.config.font
            let family = fontConfig.family
            let scale = CGFloat(scaleFactor)
            self.fontAtlas = try FontAtlas(device: device, fontName: family, fontSize: CGFloat(fontConfig.size), scale: scale)
            forceNextFrame = true
            print("Renderer: Font reloaded - \(family)")
        } catch {
            print("Renderer: Failed to reload font: \(error)")
        }
    }
    
    func updateLastInputTime(_ time: TimeInterval) {
        self.lastInputTime = time
        // Force redraw to ensure cursor state updates immediately (e.g. stops blinking)
        self.forceNextFrame = true
    }
    
    /// Recreate the font atlas when the display scale factor changes (e.g. moving window
    /// from Retina laptop to external monitor or vice versa). This re-rasterizes all glyphs
    /// at the new display's native resolution for sharp text.
    func recreateFontAtlasIfNeeded(newScale: CGFloat) {
        let currentAtlasScale = fontAtlas.scale
        // Only recreate if scale actually changed (with tolerance for float comparison)
        guard abs(newScale - currentAtlasScale) > 0.01 else { return }

        do {
            let fontConfig = ConfigManager.shared.config.font
            self.fontAtlas = try FontAtlas(device: device, fontName: fontConfig.family, fontSize: CGFloat(fontConfig.size), scale: newScale)
            print("Renderer: Font atlas recreated for new scale \(currentAtlasScale) -> \(newScale)")
            forceNextFrame = true
        } catch {
            print("Renderer: Failed to recreate font atlas for scale \(newScale): \(error)")
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        if size.width == 0 || size.height == 0 { return }

        // Log thread to see if this is Main
        print("Renderer: mtkView drawableSizeWillChange to \(size) on thread: \(Thread.current.isMainThread ? "Main" : "Background")")

        session?.lock.lock()
        defer { session?.lock.unlock() }

        viewportSize = SIMD2<Float>(Float(size.width), Float(size.height))
        // Calculate scale factor: drawable pixels / view points
        let viewWidth = view.bounds.width
        if viewWidth > 0 {
            scaleFactor = Float(size.width / viewWidth)
        }

        // Update Viewport State Only
        // WE DO NOT CALL recalculateGridSizeInternal (aether_resize) HERE!
        // That is now exclusively handled by resize() on the background thread.

        // Force a redraw so the terminal repaints with the new viewport/scale
        forceNextFrame = true
        if scrollState.viewportOffset == 0 {
             if let terminal = terminal {
                 aether_scroll_to(terminal, 0)
             }
        }

        // Force a redraw so the terminal repaints with the new grid dimensions
        forceNextFrame = true
    }
    
    // Thread-safe resize called from TerminalView (possibly background thread)
    func resize(drawableSize size: CGSize, viewWidth: CGFloat) {
        if size.width == 0 || size.height == 0 { return }

        print("Renderer: resize to \(size) on thread: \(Thread.current.isMainThread ? "Main" : "Background")")

        session?.lock.lock()
        defer { session?.lock.unlock() }

        viewportSize = SIMD2<Float>(Float(size.width), Float(size.height))

        if viewWidth > 0 {
            scaleFactor = Float(size.width / viewWidth)
        }

        // Recreate font atlas if display scale changed (e.g. moved to external monitor)
        recreateFontAtlasIfNeeded(newScale: CGFloat(scaleFactor))

        recalculateGridSizeInternal()
        
        // Force a full clear/redraw on resize to prevent "garbage" text/artifacts
        // logic: if possible, tell renderer to clear background? 
        // For now, ensuring forceNextFrame is true is best we can do in Swift.
        // The artifact might be from the PTY side. 
        
        if scrollState.viewportOffset == 0 {
             if let terminal = terminal {
                 aether_scroll_to(terminal, 0)
             }
        }
        
        forceNextFrame = true
    }
    
    func draw(in view: MTKView) {
        // Non-blocking lock attempt.
        // If the background thread is resizing (holding lock), we simply SKIP this frame.
        // This prevents the Main Thread from freezing/hanging while waiting for heavy resize ops.
        guard let session = session else { return }
        if !session.lock.try() {
            return
        }
        defer { session.lock.unlock() }
        
        guard let terminal = terminal,
              let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor else {
            print("DEBUG: draw skipped - terminal: \(terminal != nil), drawable: \(view.currentDrawable != nil), descriptor: \(view.currentRenderPassDescriptor != nil)")
            return
        }
        
        
        // REMOVED: aether_process_output(terminal)
        // This is now handled by TerminalSession's background IO loop.
        // Doing I/O on the render thread caused massive stalls and contention.

        
        // Update scroll state for UI
        let scrollInfo = aether_get_scroll_info(terminal)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Only update if changed to avoid excessive view updates
            if self.scrollState.viewportOffset != scrollInfo.viewport_offset ||
               self.scrollState.totalRows != scrollInfo.total_rows {
                self.scrollState.totalRows = scrollInfo.total_rows
                self.scrollState.visibleRows = scrollInfo.visible_rows
                self.scrollState.scrollbackRows = scrollInfo.scrollback_rows
                self.scrollState.viewportOffset = scrollInfo.viewport_offset
            }
        }
        
        // Always redraw at 30fps for smooth cursor blink.
        // The isDirty check was skipping frames when idle, preventing cursor animation.
        forceNextFrame = false
        
        // Build instance buffer from grid
        let instances = buildInstances()
        updateInstanceBuffer(instances)
        
        // Encode render commands
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        
        encoder.setRenderPipelineState(pipelineState)
        if let buffer = instanceBuffer {
            encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        }
        encoder.setVertexBytes(&viewportSize, length: MemoryLayout<SIMD2<Float>>.size, index: 1)
        encoder.setFragmentTexture(fontAtlas.texture, index: 0)
        
        // Single instanced draw call
        if !instances.isEmpty {
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: instances.count)
        }
        
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        aether_mark_clean(terminal)
    }
    
    private func buildInstances() -> [GlyphInstance] {
        var instances: [GlyphInstance] = []
        guard let terminal = terminal else { return [] }
        
        var cursor = aether_get_cursor(terminal)
        
        if let override = cursorOverride {
            cursor.row = override.row
            cursor.col = override.col
            cursor.visible = true
            // Force block style for visual selection
            cursor.style = 0 
        }
        
        let now = CACurrentMediaTime()
        let blinkRate = max(0.1, min(10.0, ConfigManager.shared.config.cursor.blinkRate))
        let blinkPeriod = 1.0 / Float(blinkRate) // seconds per full blink cycle
        
        // Smart Blink Logic
        // Smart Blink Logic
        
        // Smart Blink / Inactive Logic
        var isCursorBlinkOn = false
        if isActive {
            if ConfigManager.shared.config.cursor.smartBlink {
                let timeSinceInput = now - lastInputTime
                if timeSinceInput < 0.5 {
                    isCursorBlinkOn = true
                } else {
                    let cursorPhase = fmod(Float(now), blinkPeriod)
                    isCursorBlinkOn = cursor.visible && (cursorPhase < blinkPeriod * 0.5)
                }
            } else {
                let cursorPhase = fmod(Float(now), blinkPeriod)
                isCursorBlinkOn = cursor.visible && (cursorPhase < blinkPeriod * 0.5)
            }
            if !ConfigManager.shared.config.cursor.blink {
                isCursorBlinkOn = cursor.visible
            }
        } else {
            // Inactive: Always show cursor (no blink), but maybe diff style
            isCursorBlinkOn = cursor.visible
        }
        
        // Hide cursor while loading to avoid blinking at 0,0 (Global override)
        if session?.isLoading == true {
            isCursorBlinkOn = false
        }
        
        let ratio = scaleFactor / Float(fontAtlas.scale)
        let cw = Float(fontAtlas.cellWidth) * ratio
        let ch = Float(fontAtlas.cellHeight) * ratio
        let lineSpacing = max(1.0, min(3.0, ConfigManager.shared.config.font.lineHeight))
        let rowHeight = ch * lineSpacing // Extra vertical space between lines
        let ascentScaled = Float(fontAtlas.ascent) * ratio
        let solidRect = fontAtlas.getSolidRect()
        
        if !loggedMetrics {
            // print("Renderer: Metrics - rows: \(rows), cols: \(cols), cw: \(cw), ch: \(ch), ratio: \(ratio)")
            loggedMetrics = true
        }
        
        // Cursor Config
        let cursorLimit = ConfigManager.shared.config.cursor
        let style = cursorLimit.style
        let isBlock = (style == .block)
        
        // Selection Highlight Color
        let selHex = ConfigManager.shared.config.colors.selection ?? "#5A3399FF"
        let selRaw = ConfigManager.shared.parseColor(selHex)
        let selA = Float((selRaw >> 24) & 0xFF) / 255.0
        let selR = Float((selRaw >> 16) & 0xFF) / 255.0
        let selG = Float((selRaw >> 8) & 0xFF) / 255.0
        let selB = Float(selRaw & 0xFF) / 255.0
        let selectionBG = SIMD4<Float>(selR, selG, selB, selA)
        
        let padX = Float(ConfigManager.shared.config.window.padding.x) * scaleFactor
        let padY = Float(ConfigManager.shared.config.window.padding.y) * scaleFactor
        
        // Pass 1: Backgrounds
        let isCursorVisibleInViewport = (scrollState.viewportOffset == 0)
        
        // Pre-calculate fixed cursor color (Theme Foreground) outside loop
        let theme = ConfigManager.shared.config.colors.resolveTheme()
        let themeFgColor = colorFromARGB(ConfigManager.shared.parseColor(theme.foreground))
        
        // ascentScaled is already defined above
        let descentScaled = Float(fontAtlas.descent) * ratio
        let textHeight = ascentScaled + descentScaled
        
        // Calculate vertical centering offset for cursor to align with text
        // Text baseline is at y + ascentScaled.
        // We want the cursor block (height = textHeight) to span from (baseline - ascent) to (baseline + descent).
        // (y + ascent) - ascent = y.
        // So aligning to y is correct IF the font metrics are standard.
        // User says "more in bottom", implying rowHeight > textHeight adds space at bottom.
        // So limiting height to textHeight will fix it.
        
        for r in 0..<UInt32(rows) {
            for c in 0..<UInt32(cols) {
                // (Legacy skip logic removed)
                
                guard let cellPtr = aether_get_cell(terminal, r, c) else { continue }
                let cell = cellPtr.pointee
                
                // Flags: 7=Wide(0x80), 8=Spacer(0x100)
                let flags = cell.flags
                let isWide = (flags & 0x0080) != 0
                let isSpacer = (flags & 0x0100) != 0
                
                if isSpacer { continue } // Skip spacers, let the wide char cover it
                
                let x = Float(c) * cw + padX
                let y = Float(r) * rowHeight + padY
                
                let bgColorVal = cell.bg_color
                
                // Cursor Background Logic
                // We draw the cursor as a solid background block here in Pass 1
                // to cover the full cell area (unlike glyphs which only cover the char).
                var effectiveCellBG = colorFromARGB(bgColorVal)
                var shouldDrawBG = (bgColorVal != 0xFF000000)
                var bgH = rowHeight
                
                if isCursorBlinkOn && isBlock && isCursorVisibleInViewport && r == cursor.row && c == cursor.col {
                    // Cursor Block: Force draw background with Cursor Color (Theme FG)
                    shouldDrawBG = true
                    effectiveCellBG = themeFgColor
                    effectiveCellBG.w = 1.0 // Ensure Opacity
                    // Limit height to text height as requested
                    bgH = textHeight
                }
                
                // Draw cell BG
                if shouldDrawBG {
                     let width = isWide ? cw * 2.0 : cw
                     
                     let bgInst = GlyphInstance(
                         position: SIMD2<Float>(x, y),
                         size: SIMD2<Float>(width, bgH),
                         texCoord: SIMD2<Float>(solidRect.u, solidRect.v),
                         texSize: SIMD2<Float>(solidRect.width, solidRect.height),
                         fgColor: effectiveCellBG,
                         bgColor: effectiveCellBG,
                         flags: 0
                     )
                     instances.append(bgInst)
                }
                
                // Draw selection overlay (semi-transparent blue on top of content)
                let isSelected = aether_selection_contains(terminal, r, c)
                if isSelected {
                     let width = isWide ? cw * 2.0 : cw
                     let selInst = GlyphInstance(
                         position: SIMD2<Float>(x, y),
                         size: SIMD2<Float>(width, rowHeight),
                         texCoord: SIMD2<Float>(solidRect.u, solidRect.v),
                         texSize: SIMD2<Float>(solidRect.width, solidRect.height),
                         fgColor: selectionBG,
                         bgColor: selectionBG,
                         flags: 0
                     )
                     instances.append(selInst)
                }
            }
        }
        
        // Pass 2: Foregrounds & Cursor
        let ligaturesEnabled = ConfigManager.shared.config.font.ligatures
        
        for r in 0..<UInt32(rows) {
            var c: UInt32 = 0
            while c < UInt32(cols) {
                guard let cellPtr = aether_get_cell(terminal, r, c) else { c += 1; continue }
                let firstCell = cellPtr.pointee
                
                // Group contiguous cells with same style
                var runCells = [firstCell]
                var nextC = c + 1
                while nextC < UInt32(cols) {
                    guard let nextCellPtr = aether_get_cell(terminal, r, nextC) else { break }
                    let nextCell = nextCellPtr.pointee
                    
                    // Style matching: colors + certain flags (bold, italic, etc.)
                    // Note: We don't have bold/italic flags exposed in aether_cell yet besides the bitmask.
                    if nextCell.fg_color == firstCell.fg_color &&
                       nextCell.bg_color == firstCell.bg_color &&
                       nextCell.flags == firstCell.flags {
                        runCells.append(nextCell)
                        nextC += 1
                     } else {
                         break
                     }
                 }
                 
                 let y = Float(r) * rowHeight + padY
                
                let fgColorVal = firstCell.fg_color
                let fg = colorFromARGB(fgColorVal)
                let bg = SIMD4<Float>(0, 0, 0, 0)
                
                // Cursor logic for the start of the run (Simplified: we'll handle cursor overlaps later or split runs at cursor)
                // For now, let's just draw the shaped text. If the cursor is in the middle of a run, 
                // we might want to split the run to ensure high-contrast text works.
                
                let runChars = runCells.compactMap { (cell) -> Character? in
                    if cell.codepoint == 0 { return nil }
                    return UnicodeScalar(cell.codepoint).map { Character($0) }
                }
                let runText = String(runChars)
                
                if !runText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                    // print("Renderer: Row \(r) Col \(c) runText: '\(runText)' (count: \(runText.count))")
                }
                
                if !runText.trimmingCharacters(in: CharacterSet.whitespaces).isEmpty || runCells.contains(where: { $0.codepoint >= 0xE0B0 && $0.codepoint <= 0xE0B3 }) {
                    // Split runs if they contain Powerline or if there's a cursor in the middle for high contrast?
                    // For now, let's just handle Powerline within the run iteration if possible, 
                    // or better, treat Powerline as separate runs.
                    
                    // Actually, let's keep it simple: if a cell is Powerline, we draw it separately.
                    // If a cell is normal, we group it.
                    
                    var currentC = c
                    for cell in runCells {
                        let cellX = Float(currentC) * cw + padX
                        let isPowerline = (cell.codepoint >= 0xE0B0 && cell.codepoint <= 0xE0B3)
                        
                        if isPowerline {
                            var shaderFlags: UInt32 = UInt32(cell.flags)
                            switch cell.codepoint {
                            case 0xE0B0: shaderFlags |= 0x80000000 | (0 << 28)
                            case 0xE0B1: shaderFlags |= 0x80000000 | (1 << 28)
                            case 0xE0B2: shaderFlags |= 0x80000000 | (2 << 28)
                            case 0xE0B3: shaderFlags |= 0x80000000 | (3 << 28)
                            default: break
                            }
                            
                            let plInst = GlyphInstance(
                                position: SIMD2<Float>(cellX, y),
                                size: SIMD2<Float>(cw, ch),
                                texCoord: SIMD2<Float>(solidRect.u, solidRect.v),
                                texSize: SIMD2<Float>(solidRect.width, solidRect.height),
                                fgColor: fg,
                                bgColor: bg,
                                flags: shaderFlags
                            )
                            instances.append(plInst)
                        }
                        currentC += 1
                    }
                    
                    // Filter out Powerline from text shaping
                    let shapedText = String(runCells.compactMap { cell in
                        let isPowerline = (cell.codepoint >= 0xE0B0 && cell.codepoint <= 0xE0B3)
                        if isPowerline { return Character(" ") }
                        if cell.codepoint == 0 { return nil } // CRITICAL: Filter nulls
                        return UnicodeScalar(cell.codepoint).map { Character($0) }
                    })
                    
                    if !shapedText.trimmingCharacters(in: CharacterSet.whitespaces).isEmpty {
                        let attrString = NSMutableAttributedString(string: shapedText, attributes: [.font: fontAtlas.ctFont])
                        if !ligaturesEnabled {
                            attrString.addAttribute(NSAttributedString.Key(kCTLigatureAttributeName as String), value: 0, range: NSRange(location: 0, length: shapedText.count))
                        }
                        
                        let line = CTLineCreateWithAttributedString(attrString)
                        let runArray = CTLineGetGlyphRuns(line)
                        
                        for runIdx in 0..<CFArrayGetCount(runArray) {
                            let run = unsafeBitCast(CFArrayGetValueAtIndex(runArray, runIdx), to: CTRun.self)
                            let glyphCount = CTRunGetGlyphCount(run)
                            
                            var glyphs = [CGGlyph](repeating: 0, count: glyphCount)
                            var stringIndices = [CFIndex](repeating: 0, count: glyphCount)
                            CTRunGetGlyphs(run, CFRangeMake(0, glyphCount), &glyphs)
                            CTRunGetStringIndices(run, CFRangeMake(0, glyphCount), &stringIndices)
                            
                            let attributes = CTRunGetAttributes(run) as? [NSAttributedString.Key: Any]
                            let runFont = (attributes?[.font] as AnyObject?) as! CTFont? ?? fontAtlas.ctFont
                            
                            for i in 0..<glyphCount {
                                let g = glyphs[i]
                                let charIdx = stringIndices[i]
                                
                                let glyphInfo = fontAtlas.getGlyph(g, font: runFont, bold: false, italic: false)
                                if glyphInfo.width == 0 { continue }
                                
                                let glyphPixelW = glyphInfo.width * Float(fontAtlas.texture.width)
                                let glyphPixelH = glyphInfo.height * Float(fontAtlas.texture.height)
                                let glyphW = glyphPixelW * ratio
                                let glyphH = glyphPixelH * ratio
                                
                                // Terminal grid positioning: each character at its grid cell.
                                // This is required for column alignment (ls, tables, etc.).
                                let glyphCol = c + UInt32(charIdx)
                                let cellX = Float(glyphCol) * cw + padX
                                // Snap glyph positions to pixel grid for sharp rendering.
                                // Glyphs are rasterized at exact Retina resolution, so aligning
                                // to integer pixel coordinates prevents subpixel blur.
                                let gx = round(cellX + glyphInfo.bearingX * ratio)
                                let gy = round(y + ascentScaled - (glyphInfo.bearingY * ratio + glyphH))
                                
                                let inst = GlyphInstance(
                                    position: SIMD2<Float>(gx, gy),
                                    size: SIMD2<Float>(glyphW, glyphH),
                                    texCoord: SIMD2<Float>(glyphInfo.u, glyphInfo.v),
                                    texSize: SIMD2<Float>(glyphInfo.width, glyphInfo.height),
                                    fgColor: fg,
                                    bgColor: bg,
                                    flags: UInt32(firstCell.flags)
                                )
                                instances.append(inst)
                            }
                        }
                    }
                }
                
                // Cursor Geometry Logic (Beam / Underline)
                for currentC in c..<nextC {
                    let cellX = Float(currentC) * cw + padX
                    let isCursorVisibleInViewport = (scrollState.viewportOffset == 0)
                    
                    var effectiveStyle = ConfigManager.shared.config.cursor.style
                    switch cursor.style {
                    case 1: effectiveStyle = .underline
                    case 2: effectiveStyle = .beam
                    default: break 
                    }
                    
                    let currentStyle = effectiveStyle
                    let isBlock = (currentStyle == .block)
                    
                    if isCursorBlinkOn && !isBlock && isCursorVisibleInViewport && r == cursor.row && currentC == cursor.col {
                        let cursorColor = isActive ? colorFromARGB(0xFFFFFFFF) : SIMD4<Float>(0.5, 0.5, 0.5, 1.0)
                        
                        var rectSize: SIMD2<Float> = .zero
                        var rectPos: SIMD2<Float> = SIMD2<Float>(cellX, y)
                        
                        let textHeight = ascentScaled + descentScaled
                        
                        if currentStyle == .beam {
                            rectSize = SIMD2<Float>(2.0, textHeight)
                        } else if currentStyle == .underline {
                            rectSize = SIMD2<Float>(cw, 2.0)
                            rectPos.y = y + rowHeight - 2.0
                        }
                        
                        if rectSize.x > 0 {
                            let cursorInst = GlyphInstance(
                                position: rectPos,
                                size: rectSize,
                                texCoord: SIMD2<Float>(solidRect.u, solidRect.v),
                                texSize: SIMD2<Float>(solidRect.width, solidRect.height),
                                fgColor: cursorColor,
                                bgColor: cursorColor,
                                flags: 0
                            )
                            instances.append(cursorInst)
                        }
                    }
                }
                
                c = nextC
            }
        }
        
        return instances
    }
    
    private var paddingX: Float { Float(ConfigManager.shared.config.window.padding.x) }
    private var paddingY: Float { Float(ConfigManager.shared.config.window.padding.y) }
    
    /// Convert view point (local coords) to Grid (row, col)
    func convertPointToGrid(_ point: CGPoint) -> (uint: UInt32, row: UInt32, col: UInt32)? {
        guard viewportSize.x > 0 && viewportSize.y > 0 else { return nil }
        
        // Adjust for padding (in points)
        let x = point.x - CGFloat(paddingX)
        let y = point.y - CGFloat(paddingY)
        
        let ratio = scaleFactor / Float(fontAtlas.scale)
        let atlasW = Float(fontAtlas.cellWidth)
        let atlasH = Float(fontAtlas.cellHeight)
        
        let lineSpacing = max(1.0, min(3.0, ConfigManager.shared.config.font.lineHeight))
        
        let effectiveW = Double(atlasW * ratio / scaleFactor) // Points
        let effectiveRowH = Double(atlasH * ratio * Float(lineSpacing) / scaleFactor) // Points
        
        let c = Int(Double(x) / effectiveW)
        let r = Int(Double(y) / effectiveRowH)
        
        if c >= 0 && c < cols && r >= 0 && r < rows {
             return (0, UInt32(r), UInt32(c))
        }
        return nil
    }
    
    private func updateInstanceBuffer(_ instances: [GlyphInstance]) {
        guard !instances.isEmpty else { return }
        let size = instances.count * MemoryLayout<GlyphInstance>.stride
        if instanceBuffer == nil || instanceBuffer!.length < size {
            instanceBuffer = device.makeBuffer(length: size, options: .storageModeShared)
        }
        guard let buffer = instanceBuffer else { return }
        buffer.contents().copyMemory(from: instances, byteCount: size)
    }
    
    private func recalculateGridSizeInternal() {
        guard viewportSize.x > 0 && viewportSize.y > 0 else { return }
        
        // PADDING is in points. viewportSize is in pixels.
        // We need consistent units. Let's work entirely in physical pixels (backing store).
        
        // FontAtlas gives metrics in pixels if scale was passed correctly during init.
        // However, let's be explicit:
        // cellWidth/Height in FontAtlas * (current_view_scale / font_atlas_scale) = physical pixels on screen of a cell?
        
        let ratio = scaleFactor / Float(fontAtlas.scale)
        let cellW = Float(fontAtlas.cellWidth) * ratio
        let cellH = Float(fontAtlas.cellHeight) * ratio
        let lineSpacing = max(1.0, min(3.0, ConfigManager.shared.config.font.lineHeight))
        let rowH = cellH * lineSpacing
        
        let padX = paddingX * scaleFactor
        let padY = paddingY * scaleFactor
        let availableW = max(0, viewportSize.x - (padX * 2))
        let availableH = max(0, viewportSize.y - (padY * 2))
        
        // Enforce minimum dimensions (e.g. 2x2) to prevent core crashes
        let newCols = max(2, Int(availableW / cellW))
        let newRows = max(2, Int(availableH / rowH))
        
        if newCols != cols || newRows != rows {
            cols = newCols
            rows = newRows
            if let terminal = terminal {
                _ = aether_resize(terminal, UInt32(rows), UInt32(cols))
                // Force redraw after resize to prevent "disappearing content"
                forceNextFrame = true
            }
        }
    }
    
    private var colorMap: [UInt32: UInt32] = [:]
    
    // ... (init, etc.) ...
    
    private var forceNextFrame = false
    private var loggedMetrics = false

    private func applyInitialState() {
        guard let terminal = terminal else { return }
        
        // Sync Dimensions
        self.rows = Int(aether_get_rows(terminal))
        self.cols = Int(aether_get_cols(terminal))
        
        // Apply Cursor Style
        let style = ConfigManager.shared.config.cursor.style
        var zigStyle: UInt8 = 0
        switch style {
        case .block: zigStyle = 0
        case .underline: zigStyle = 1
        case .beam: zigStyle = 2
        }
        aether_set_cursor_style(terminal, zigStyle)
        
        forceNextFrame = true
    }
    
    func applyTheme(_ theme: Theme) {
        colorMap.removeAll()
        // Default ANSI mapping (Zig internal defaults -> Theme Palette)
        let defaults: [UInt32] = [
            0xFF000000, // Black
            0xFFCD0000, // Red
            0xFF00CD00, // Green
            0xFFCDCD00, // Yellow
            0xFF0000EE, // Blue
            0xFFCD00CD, // Magenta
            0xFF00CDCD, // Cyan
            0xFFE5E5E5, // White
            0xFF7F7F7F, // Bright Black
            0xFFFF0000, // Bright Red
            0xFF00FF00, // Bright Green
            0xFFFFFF00, // Bright Yellow
            0xFF5C5CFF, // Bright Blue
            0xFFFF00FF, // Bright Magenta
            0xFF00FFFF, // Bright Cyan
            0xFFFFFFFF  // Bright White
        ]
        
        let parser = ConfigManager.shared
        
        for (i, defaultColor) in defaults.enumerated() {
            if i < theme.palette.count {
                let themeColor = parser.parseColor(theme.palette[i])
                colorMap[defaultColor] = themeColor
            }
        }
        
        // Force redraw to apply colors immediately
        forceNextFrame = true
    }
    
    // Legacy support for menu
    func setTheme(_ name: String) {
        // Update global config
        ConfigManager.shared.config.colors.scheme = name
        let theme = ConfigManager.shared.config.colors.resolveTheme()
        applyTheme(theme)
    }

    /// Decode ARGB color from Zig terminal (format: 0xAARRGGBB) using Theme mapping
    private func colorFromARGB(_ color: UInt32) -> SIMD4<Float> {
        let mapped = colorMap[color] ?? color
        let a = Float((mapped >> 24) & 0xFF) / 255.0
        let r = Float((mapped >> 16) & 0xFF) / 255.0
        let g = Float((mapped >> 8) & 0xFF) / 255.0
        let b = Float(mapped & 0xFF) / 255.0
        return SIMD4<Float>(r, g, b, a)
    }

}

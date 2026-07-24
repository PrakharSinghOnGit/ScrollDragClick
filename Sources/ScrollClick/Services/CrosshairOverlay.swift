import Cocoa

/// A borderless, click-through overlay window that draws a crosshair
/// at the exact centre of the primary display.
/// The window sits at the highest window level and ignores all input.
public final class CrosshairOverlay {
    public static let shared = CrosshairOverlay()

    private var window: NSWindow?
    private var view: CrosshairView?

    private init() {}

    // MARK: - Show / Hide

    public func show(config: AppConfig) {
        if window == nil { makeWindow() }

        view?.update(
            shape:     config.crosshairShape,
            colorHex:  config.crosshairColorHex,
            size:      config.crosshairSize,
            thickness: config.crosshairThickness,
            opacity:   config.crosshairOpacity
        )
        window?.alphaValue = CGFloat(config.crosshairOpacity)
        window?.orderFrontRegardless()
    }

    public func hide() {
        window?.orderOut(nil)
    }

    public func update(config: AppConfig) {
        guard let w = window, w.isVisible else { return }
        view?.update(
            shape:     config.crosshairShape,
            colorHex:  config.crosshairColorHex,
            size:      config.crosshairSize,
            thickness: config.crosshairThickness,
            opacity:   config.crosshairOpacity
        )
    }

    // MARK: - Window Setup

    private func makeWindow() {
        guard let screen = NSScreen.main else { return }

        // Full-screen borderless window at the top level — ignores all mouse input.
        let win = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)) + 1)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let crosshairView = CrosshairView(frame: screen.frame)
        win.contentView = crosshairView

        self.window = win
        self.view = crosshairView
    }
}

// MARK: - CrosshairView

private final class CrosshairView: NSView {
    private var shape: CrosshairShape = .cross
    private var color: NSColor = .red
    private var size: Int = 20
    private var thickness: Int = 2
    private var opacity: Double = 1.0

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = CGColor.clear
    }
    required init?(coder: NSCoder) { fatalError() }

    func update(shape: CrosshairShape, colorHex: String, size: Int, thickness: Int, opacity: Double) {
        self.shape     = shape
        self.color     = NSColor(hex: colorHex) ?? .red
        self.size      = max(2, size)
        self.thickness = max(1, thickness)
        self.opacity   = opacity
        needsDisplay   = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Centre of the view == centre of the screen (the window covers the whole screen)
        let cx = bounds.midX
        let cy = bounds.midY
        let r  = CGFloat(size)
        let t  = CGFloat(thickness)

        ctx.setStrokeColor(color.withAlphaComponent(CGFloat(opacity)).cgColor)
        ctx.setFillColor(color.withAlphaComponent(CGFloat(opacity)).cgColor)
        ctx.setLineWidth(t)
        ctx.setLineCap(.round)

        switch shape {
        case .dot:
            // Filled circle centred on pixel
            let dotR = r * 0.5
            ctx.fillEllipse(in: CGRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2))

        case .cross:
            // Horizontal arm
            ctx.move(to: CGPoint(x: cx - r, y: cy))
            ctx.addLine(to: CGPoint(x: cx + r, y: cy))
            // Vertical arm
            ctx.move(to: CGPoint(x: cx, y: cy - r))
            ctx.addLine(to: CGPoint(x: cx, y: cy + r))
            ctx.strokePath()
        }
    }
}

// MARK: - NSColor hex helper

private extension NSColor {
    convenience init?(hex: String) {
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("#") { str = String(str.dropFirst()) }
        guard str.count == 6, let value = UInt64(str, radix: 16) else { return nil }
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >>  8) & 0xFF) / 255
        let b = CGFloat( value        & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

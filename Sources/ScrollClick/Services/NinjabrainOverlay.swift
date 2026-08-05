import Cocoa
import SwiftUI

public final class NinjabrainOverlay {
    public static let shared = NinjabrainOverlay()
    
    private var window: NSWindow?
    
    private init() {}
    
    public func show(config: AppConfig) {
        if window == nil { makeWindow() }
        
        // Update position and show
        if let w = window {
            let screenHeight = NSScreen.main?.frame.height ?? 1080
            // Convert coordinate system from top-left to bottom-left
            let yPos = screenHeight - CGFloat(config.ninjabrainY) - w.frame.height
            w.setFrameOrigin(NSPoint(x: CGFloat(config.ninjabrainX), y: yPos))
            w.orderFrontRegardless()
        }
        
        NinjabrainClient.shared.start(pollRateMs: config.ninjabrainPollRateMs)
    }
    
    public func hide() {
        window?.orderOut(nil)
        NinjabrainClient.shared.stop()
    }
    
    public func update(config: AppConfig) {
        guard let w = window, w.isVisible else { return }
        
        let screenHeight = NSScreen.main?.frame.height ?? 1080
        let yPos = screenHeight - CGFloat(config.ninjabrainY) - w.frame.height
        w.setFrameOrigin(NSPoint(x: CGFloat(config.ninjabrainX), y: yPos))
        
        NinjabrainClient.shared.start(pollRateMs: config.ninjabrainPollRateMs)
    }
    
    private func makeWindow() {
        // Create an arbitrary rect; it will resize automatically via NSHostingView if needed, 
        // but we'll set a fixed size for the window container to allow text to fit.
        let rect = NSRect(x: 0, y: 0, width: 600, height: 200)
        let win = NSWindow(
            contentRect: rect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)) + 1)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        
        win.contentView = NSHostingView(rootView: NinjabrainView())
        
        self.window = win
    }
}

struct NinjabrainView: View {
    @ObservedObject var client = NinjabrainClient.shared
    
    private var config: AppConfig {
        ConfigStore.shared.config
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if client.topPredictions.isEmpty {
                // Keep the view layout stable even when empty
                Text("Waiting for Ninjabrain-Bot...")
                    .font(.system(size: CGFloat(config.ninjabrainFontSize), weight: .bold))
                    .foregroundColor(Color(nsColor: NSColor(hex: config.ninjabrainColorHex) ?? .white))
                    .shadow(color: .black, radius: 1, x: 1, y: 1)
                    .shadow(color: .black, radius: 1, x: -1, y: -1)
                    .shadow(color: .black, radius: 1, x: 1, y: -1)
                    .shadow(color: .black, radius: 1, x: -1, y: 1)
            } else {
                ForEach(client.topPredictions) { pred in
                    HStack(spacing: 12) {
                        borderedText(pred.coords)
                        borderedText(pred.netherCoords)
                        borderedText(pred.percent)
                        borderedText(pred.angle)
                        borderedText(pred.distance)
                    }
                }
            }
        }
        .padding(8)
        // Ensure the background is completely transparent
        .background(Color.clear)
        // Force the frame to top-left so window positioning works cleanly
        .frame(width: 600, height: 200, alignment: .topLeading)
    }
    
    @ViewBuilder
    private func borderedText(_ text: String) -> some View {
        let size = CGFloat(config.ninjabrainFontSize)
        let color = Color(nsColor: NSColor(hex: config.ninjabrainColorHex) ?? .white)
        
        Text(text)
            .font(.system(size: size, weight: .bold, design: .monospaced))
            .foregroundColor(color)
            // Multiple shadows to create a thick outline/border effect for readability
            .shadow(color: .black, radius: 1, x: 1, y: 1)
            .shadow(color: .black, radius: 1, x: -1, y: -1)
            .shadow(color: .black, radius: 1, x: 1, y: -1)
            .shadow(color: .black, radius: 1, x: -1, y: 1)
    }
}

// Ensure hex parsing is available (can use the one from CrosshairOverlay if it was internal, 
// but it was fileprivate there. We'll duplicate it safely as fileprivate here).
fileprivate extension NSColor {
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

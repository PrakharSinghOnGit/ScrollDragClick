import Foundation
import Cocoa
import ApplicationServices

public final class AccessibilityManager: ObservableObject {
    public static let shared = AccessibilityManager()
    
    @Published public var isTrusted: Bool = false
    
    private var timer: Timer?
    
    private init() {
        checkPermission()
        startMonitoring()
    }
    
    public func checkPermission() {
        let trusted = AXIsProcessTrusted()
        DispatchQueue.main.async {
            self.isTrusted = trusted
        }
    }
    
    public func promptPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
    
    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    public func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.checkPermission()
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}

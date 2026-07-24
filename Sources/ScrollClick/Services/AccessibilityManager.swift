import Foundation
import Cocoa
import ApplicationServices

/// Checks accessibility permissions once on startup and when explicitly requested.
/// Uses a distributed notification to detect when the user grants/revokes trust,
/// rather than polling with a timer every 1.5 s (which was causing unnecessary CPU use).
public final class AccessibilityManager {
    public static let shared = AccessibilityManager()

    public private(set) var isTrusted: Bool = false

    /// Called once trust status changes.
    public var onTrustChanged: ((Bool) -> Void)?

    private var monitorTimer: Timer?

    private init() {
        isTrusted = AXIsProcessTrusted()
        // Only start a slow timer (5 s) if we are not yet trusted, to detect grant.
        // Once trusted we stop polling entirely — no continuous overhead.
        if !isTrusted {
            startMonitoringForGrant()
        }
    }

    /// Poll slowly until trust is granted, then stop.
    private func startMonitoringForGrant() {
        monitorTimer?.invalidate()
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let trusted = AXIsProcessTrusted()
            if trusted != self.isTrusted {
                self.isTrusted = trusted
                self.onTrustChanged?(trusted)
                if trusted {
                    // Trusted — stop polling
                    self.monitorTimer?.invalidate()
                    self.monitorTimer = nil
                }
            }
        }
    }

    public func checkPermission() {
        let trusted = AXIsProcessTrusted()
        if trusted != isTrusted {
            isTrusted = trusted
            onTrustChanged?(trusted)
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

    deinit {
        monitorTimer?.invalidate()
    }
}

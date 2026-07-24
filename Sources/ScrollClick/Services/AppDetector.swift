import Foundation
import Cocoa

/// Tracks the frontmost application using NSWorkspace notifications instead of a polling timer.
/// This is event-driven and has zero CPU overhead between app switches.
public final class AppDetector {
    public static let shared = AppDetector()

    private(set) public var frontmostApp: NSRunningApplication?

    private var activationObserver: Any?

    private init() {
        frontmostApp = NSWorkspace.shared.frontmostApplication

        // Use workspace notifications — fired by the OS on each app switch, zero polling cost.
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            self?.frontmostApp = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        }
    }

    deinit {
        if let obs = activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
    }

    /// Returns true if the currently frontmost application matches the configured target.
    /// Called from the CGEventTap callback — must be fast and thread-safe.
    /// This is a pure read — no Objective-C calls except on the already-cached value.
    public func isTargetAppActive(config: AppConfig) -> Bool {
        if config.targetAppMode == .all { return true }

        guard let front = frontmostApp else { return false }

        let target = config.targetAppName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let targetBundle = config.targetAppBundleId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if target.isEmpty && targetBundle.isEmpty { return true }

        let frontName   = (front.localizedName ?? "").lowercased()
        let frontExec   = (front.executableURL?.lastPathComponent ?? "").lowercased()
        let frontBundle = (front.bundleIdentifier ?? "").lowercased()

        if !targetBundle.isEmpty && frontBundle.contains(targetBundle) { return true }
        if !target.isEmpty {
            if frontName.contains(target) || frontExec.contains(target) || frontBundle.contains(target) {
                return true
            }
        }
        return false
    }
}

import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as a pure background accessory — no Dock icon, no menu bar app menu
        NSApp.setActivationPolicy(.accessory)

        // Wire accessibility trust-change to engine start
        AccessibilityManager.shared.onTrustChanged = { trusted in
            DispatchQueue.main.async {
                if trusted { ScrollTapEngine.shared.start() }
            }
        }

        statusBarController = StatusBarController()

        let cfg = ConfigStore.shared.config

        // Start engine if permitted
        if cfg.isEnabled {
            ScrollTapEngine.shared.start()
        }

        // Show crosshair if configured
        if cfg.crosshairEnabled {
            CrosshairOverlay.shared.show(config: cfg)
        }

        // Show Ninjabrain overlay if configured
        if cfg.ninjabrainEnabled {
            NinjabrainOverlay.shared.show(config: cfg)
        }

        // Prompt for accessibility if not yet granted
        if !AccessibilityManager.shared.isTrusted {
            showAccessibilityAlert()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        ScrollTapEngine.shared.stop()
        CrosshairOverlay.shared.hide()
        NinjabrainOverlay.shared.hide()
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "ScrollClick needs Accessibility Permission"
        alert.informativeText = "Open System Settings → Privacy & Security → Accessibility and enable ScrollClick."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            AccessibilityManager.shared.promptPermission()
            AccessibilityManager.shared.openAccessibilitySettings()
        }
    }
}

let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate
app.run()

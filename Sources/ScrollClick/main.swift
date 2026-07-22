import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure app runs in background mode (no dock icon unless settings window is focused)
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize Status Bar Menu
        statusBarController = StatusBarController()
        
        // Start CGEventTap engine
        ScrollTapEngine.shared.start()
        
        // Prompt for accessibility if not yet granted
        if !AccessibilityManager.shared.isTrusted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                StatusBarController.sharedWindowPrompt()
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        ScrollTapEngine.shared.stop()
    }
}

extension StatusBarController {
    static func sharedWindowPrompt() {
        let alert = NSAlert()
        alert.messageText = "ScrollClick Accessibility Access Needed"
        alert.informativeText = "ScrollClick needs Accessibility permission in System Settings to detect mouse scrolls and perform clicks in Minecraft."
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

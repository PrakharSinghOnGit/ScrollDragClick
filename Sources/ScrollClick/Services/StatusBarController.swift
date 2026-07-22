import Cocoa
import SwiftUI
import Combine

public final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var settingsStore = SettingsStore.shared
    private var cancellables = Set<AnyCancellable>()
    
    public override init() {
        super.init()
        setupStatusItem()
        observeSettings()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "computermouse.fill", accessibilityDescription: "ScrollClick")
            button.target = self
        }
        
        updateMenu()
    }
    
    private func observeSettings() {
        settingsStore.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateMenu()
                }
            }
            .store(in: &cancellables)
    }
    
    public func updateMenu() {
        let menu = NSMenu()
        
        // Header
        let titleItem = NSMenuItem(title: "ScrollClick v1.0", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Enable Toggle
        let toggleTitle = settingsStore.isEnabled ? "Status: Active (Click to Pause)" : "Status: Paused (Click to Enable)"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleEnabled), keyEquivalent: "t")
        toggleItem.target = self
        toggleItem.state = settingsStore.isEnabled ? .on : .off
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Target App Info
        let targetText = settingsStore.targetAppMode == .all ? "Target: All Applications" : "Target: \(settingsStore.targetAppName)"
        let targetItem = NSMenuItem(title: targetText, action: nil, keyEquivalent: "")
        targetItem.isEnabled = false
        menu.addItem(targetItem)
        
        // Click Configuration Info
        let ratioText: String
        if settingsStore.ratioMode == .clicksPerScroll {
            ratioText = "Config: 1 Scroll = \(settingsStore.clicksPerScroll) Clicks"
        } else {
            ratioText = "Config: \(settingsStore.scrollsPerClick) Scrolls = 1 Click"
        }
        let ratioItem = NSMenuItem(title: ratioText, action: nil, keyEquivalent: "")
        ratioItem.isEnabled = false
        menu.addItem(ratioItem)
        
        // Mouse Button Info
        let buttonItem = NSMenuItem(title: "Trigger: \(settingsStore.mouseButton.shortName)", action: nil, keyEquivalent: "")
        buttonItem.isEnabled = false
        menu.addItem(buttonItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings Window
        let settingsItem = NSMenuItem(title: "Preferences & Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        // Check Accessibility
        let accessItem = NSMenuItem(title: "Check Accessibility Permission", action: #selector(checkAccessibility), keyEquivalent: "")
        accessItem.target = self
        menu.addItem(accessItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit ScrollClick", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc private func toggleEnabled() {
        settingsStore.isEnabled.toggle()
    }
    
    @objc public func openSettings() {
        if settingsWindow == nil {
            let contentView = SettingsView()
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 540, height: 640),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "ScrollClick Settings"
            window.contentView = NSHostingView(rootView: contentView)
            window.isReleasedWhenClosed = false
            self.settingsWindow = window
        }
        
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    
    @objc private func checkAccessibility() {
        AccessibilityManager.shared.checkPermission()
        if !AccessibilityManager.shared.isTrusted {
            AccessibilityManager.shared.promptPermission()
            AccessibilityManager.shared.openAccessibilitySettings()
        } else {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Granted"
            alert.informativeText = "ScrollClick has full permission to intercept scroll events and generate clicks."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

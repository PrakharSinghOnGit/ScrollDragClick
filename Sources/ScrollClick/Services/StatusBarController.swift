import Cocoa

/// Minimal menu bar controller. No settings window — everything lives in the config file.
/// Menu items: Enable/Disable toggle | Open Config File | Crosshair toggle | Quit
public final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private let store = ConfigStore.shared

    public override init() {
        super.init()
        setupStatusItem()
        buildMenu()

        // Rebuild menu whenever config changes (rare — user edits file manually or we toggle)
        store.onChange = { [weak self] in
            DispatchQueue.main.async { self?.buildMenu() }
        }

        // Update icon when engine state changes
        ScrollTapEngine.shared.onStateChange = { [weak self] _ in
            DispatchQueue.main.async { self?.buildMenu() }
        }
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon()
    }

    private func updateIcon() {
        if let button = statusItem.button {
            let enabled = store.config.isEnabled
            let symbolName = enabled ? "computermouse.fill" : "computermouse"
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "ScrollClick")
            button.image?.isTemplate = true
        }
    }

    // MARK: - Menu

    func buildMenu() {
        let menu = NSMenu()

        // -- Header --
        let header = NSMenuItem(title: "ScrollClick", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        menu.addItem(.separator())

        // -- Enable / Disable --
        let enabled = store.config.isEnabled
        let toggleTitle = enabled ? "Enabled  ✓" : "Disabled  ✗"
        let toggle = NSMenuItem(title: toggleTitle, action: #selector(toggleEnabled), keyEquivalent: "e")
        toggle.target = self
        menu.addItem(toggle)

        menu.addItem(.separator())

        // -- Crosshair toggle --
        let crossTitle = store.config.crosshairEnabled ? "Hide Crosshair" : "Show Crosshair"
        let crossItem = NSMenuItem(title: crossTitle, action: #selector(toggleCrosshair), keyEquivalent: "x")
        crossItem.target = self
        menu.addItem(crossItem)

        // -- Ninjabrain toggle --
        let ninjaTitle = store.config.ninjabrainEnabled ? "Hide Ninjabrain" : "Show Ninjabrain"
        let ninjaItem = NSMenuItem(title: ninjaTitle, action: #selector(toggleNinjabrain), keyEquivalent: "n")
        ninjaItem.target = self
        menu.addItem(ninjaItem)

        menu.addItem(.separator())

        // -- Config file --
        let configItem = NSMenuItem(title: "Open Config File…", action: #selector(openConfig), keyEquivalent: ",")
        configItem.target = self
        menu.addItem(configItem)

        // -- Reload config --
        let reloadItem = NSMenuItem(title: "Reload Config", action: #selector(reloadConfig), keyEquivalent: "r")
        reloadItem.target = self
        menu.addItem(reloadItem)

        menu.addItem(.separator())

        // -- Accessibility --
        if !AccessibilityManager.shared.isTrusted {
            let axItem = NSMenuItem(title: "⚠️ Grant Accessibility Permission", action: #selector(grantAccess), keyEquivalent: "")
            axItem.target = self
            menu.addItem(axItem)
            menu.addItem(.separator())
        }

        // -- Quit --
        let quit = NSMenuItem(title: "Quit ScrollClick", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        updateIcon()
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        store.update { $0.isEnabled.toggle() }
        if store.config.isEnabled {
            ScrollTapEngine.shared.start()
        } else {
            ScrollTapEngine.shared.stop()
        }
    }

    @objc private func toggleCrosshair() {
        store.update { $0.crosshairEnabled.toggle() }
        let cfg = store.config
        if cfg.crosshairEnabled {
            CrosshairOverlay.shared.show(config: cfg)
        } else {
            CrosshairOverlay.shared.hide()
        }
    }

    @objc private func toggleNinjabrain() {
        store.update { $0.ninjabrainEnabled.toggle() }
        let cfg = store.config
        if cfg.ninjabrainEnabled {
            NinjabrainOverlay.shared.show(config: cfg)
        } else {
            NinjabrainOverlay.shared.hide()
        }
    }

    @objc private func openConfig() {
        // Open the config file in the default text editor
        NSWorkspace.shared.open(URL(fileURLWithPath: store.configFilePath))
    }

    @objc private func reloadConfig() {
        store.reload()
        let cfg = store.config
        // Re-sync crosshair state
        if cfg.crosshairEnabled {
            CrosshairOverlay.shared.show(config: cfg)
        } else {
            CrosshairOverlay.shared.hide()
        }
        // Re-sync ninjabrain state
        if cfg.ninjabrainEnabled {
            NinjabrainOverlay.shared.update(config: cfg)
            NinjabrainOverlay.shared.show(config: cfg)
        } else {
            NinjabrainOverlay.shared.hide()
        }
        // Re-sync engine state
        if cfg.isEnabled && !ScrollTapEngine.shared.isRunning {
            ScrollTapEngine.shared.start()
        } else if !cfg.isEnabled && ScrollTapEngine.shared.isRunning {
            ScrollTapEngine.shared.stop()
        }
    }

    @objc private func grantAccess() {
        AccessibilityManager.shared.promptPermission()
        AccessibilityManager.shared.openAccessibilitySettings()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

import Foundation
import Cocoa

public struct RunningAppInfo: Identifiable, Hashable {
    public var id: String { bundleIdentifier ?? name }
    public let name: String
    public let bundleIdentifier: String?
    public let icon: NSImage?
    public let processIdentifier: pid_t
}

public final class AppDetector: ObservableObject {
    public static let shared = AppDetector()
    
    @Published public var frontmostAppName: String = ""
    @Published public var frontmostAppBundleId: String = ""
    @Published public var searchText: String = ""
    @Published public var runningApps: [RunningAppInfo] = []
    
    private var timer: Timer?
    
    private init() {
        updateFrontmostApp()
        refreshRunningApps()
        startMonitoring()
    }
    
    public func refreshRunningApps() {
        let apps = getRunningApplications()
        DispatchQueue.main.async {
            self.runningApps = apps
        }
    }
    
    public func updateFrontmostApp() {
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let name = frontApp.localizedName ?? frontApp.executableURL?.lastPathComponent ?? "Unknown"
            let bundleId = frontApp.bundleIdentifier ?? ""
            
            DispatchQueue.main.async {
                self.frontmostAppName = name
                self.frontmostAppBundleId = bundleId
            }
        }
    }
    
    public func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateFrontmostApp()
        }
    }
    
    public func getRunningApplications() -> [RunningAppInfo] {
        let apps = NSWorkspace.shared.runningApplications
        var list: [RunningAppInfo] = []
        for app in apps {
            guard app.activationPolicy == .regular || app.localizedName != nil else { continue }
            let name = app.localizedName ?? app.executableURL?.lastPathComponent ?? ""
            if name.isEmpty { continue }
            list.append(RunningAppInfo(
                name: name,
                bundleIdentifier: app.bundleIdentifier,
                icon: app.icon,
                processIdentifier: app.processIdentifier
            ))
        }
        return list.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
    
    public func isTargetAppActive(settings: SettingsStore) -> Bool {
        if settings.targetAppMode == .all {
            return true
        }
        
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }
        
        let frontName = (frontApp.localizedName ?? "").lowercased()
        let frontExec = (frontApp.executableURL?.lastPathComponent ?? "").lowercased()
        let frontBundleId = (frontApp.bundleIdentifier ?? "").lowercased()
        
        let target = settings.targetAppName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let targetBundle = settings.targetAppBundleId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if target.isEmpty && targetBundle.isEmpty {
            return true
        }
        
        // Exact or substring match for flexibility (e.g. "Minecraft", "java", "org.lwjgl.glfw", "Lunar Client")
        if !targetBundle.isEmpty && frontBundleId.contains(targetBundle) {
            return true
        }
        if !target.isEmpty {
            if frontName.contains(target) || frontExec.contains(target) || frontBundleId.contains(target) {
                return true
            }
        }
        
        return false
    }
    
    deinit {
        timer?.invalidate()
    }
}

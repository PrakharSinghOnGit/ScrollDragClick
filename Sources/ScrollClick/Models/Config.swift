import Foundation
import Cocoa

// MARK: - Enums

public enum TargetAppMode: String, Codable { case all, specific }
public enum RatioMode: String, Codable { case clicksPerScroll, scrollsPerClick }
public enum ScrollDirectionOption: String, Codable { case both, downOnly, upOnly }
public enum MouseButtonOption: String, Codable { case left, right, middle, button4, button5

    public var shortName: String {
        switch self {
        case .left:    return "Left Click"
        case .right:   return "Right Click"
        case .middle:  return "Middle Click"
        case .button4: return "Button 4"
        case .button5: return "Button 5"
        }
    }
}

public enum CrosshairShape: String, Codable { case dot, cross }

// MARK: - Config Struct

public struct AppConfig: Codable {
    // Core
    public var isEnabled: Bool = true

    // Target application
    public var targetAppMode: TargetAppMode = .specific
    public var targetAppName: String = "Minecraft"
    public var targetAppBundleId: String = ""

    // Click behavior
    public var ratioMode: RatioMode = .clicksPerScroll
    public var clicksPerScroll: Int = 1
    public var scrollsPerClick: Int = 2
    public var clickDelayMs: Int = 5
    public var scrollDirection: ScrollDirectionOption = .both
    public var mouseButton: MouseButtonOption = .left
    public var suppressOriginalScroll: Bool = true

    // Crosshair
    public var crosshairEnabled: Bool = false
    public var crosshairShape: CrosshairShape = .cross
    public var crosshairColorHex: String = "#FF0000"
    public var crosshairSize: Int = 20       // px: radius for cross arms / radius for dot
    public var crosshairThickness: Int = 2   // px: line width (cross only)
    public var crosshairOpacity: Double = 1.0

    // Ninjabrain Bot Overlay
    public var ninjabrainEnabled: Bool = false
    public var ninjabrainX: Double = 20.0
    public var ninjabrainY: Double = 20.0
    public var ninjabrainMaxRows: Int = 3
    public var ninjabrainPollRateMs: Int = 200
    public var ninjabrainFontSize: Double = 14.0
    public var ninjabrainColorHex: String = "#FFFFFF"
}

// MARK: - ConfigStore

public final class ConfigStore {
    public static let shared = ConfigStore()

    private let configURL: URL
    private(set) public var config: AppConfig

    // Lightweight change notification (avoids @Published overhead)
    public var onChange: (() -> Void)?

    private init() {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/scrollclick", isDirectory: true)
        configURL = dir.appendingPathComponent("config.json")

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        config = ConfigStore.load(from: configURL)
    }

    private static func load(from url: URL) -> AppConfig {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return AppConfig()
        }
        return decoded
    }

    public func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }
        try? data.write(to: configURL, options: .atomic)
    }

    public func reload() {
        config = ConfigStore.load(from: configURL)
        onChange?()
    }

    /// Update a value and persist, then notify observers.
    public func update(_ block: (inout AppConfig) -> Void) {
        block(&config)
        save()
        onChange?()
    }

    public var configFilePath: String { configURL.path }
}

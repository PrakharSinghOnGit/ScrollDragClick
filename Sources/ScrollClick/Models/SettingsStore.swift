import Foundation
import Combine
import SwiftUI

public enum TargetAppMode: String, CaseIterable, Identifiable, Codable {
    case all = "All Applications"
    case specific = "Specific Application"
    
    public var id: String { rawValue }
}

public enum RatioMode: String, CaseIterable, Identifiable, Codable {
    case clicksPerScroll = "Clicks per Scroll Tick"
    case scrollsPerClick = "Scroll Ticks per Click"
    
    public var id: String { rawValue }
}

public enum ScrollDirectionOption: String, CaseIterable, Identifiable, Codable {
    case both = "Both (Up & Down)"
    case downOnly = "Scroll Down Only"
    case upOnly = "Scroll Up Only"
    
    public var id: String { rawValue }
}

public enum MouseButtonOption: String, CaseIterable, Identifiable, Codable {
    case left = "Left Click (Button 1)"
    case right = "Right Click (Button 2)"
    case middle = "Middle Click (Button 3)"
    case button4 = "Mouse Button 4"
    case button5 = "Mouse Button 5"
    
    public var id: String { rawValue }
    
    public var shortName: String {
        switch self {
        case .left: return "Left Click"
        case .right: return "Right Click"
        case .middle: return "Middle Click"
        case .button4: return "Button 4"
        case .button5: return "Button 5"
        }
    }
}

public final class SettingsStore: ObservableObject {
    public static let shared = SettingsStore()
    
    @AppStorage("isEnabled") public var isEnabled: Bool = true {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("targetAppMode") public var targetAppModeRaw: String = TargetAppMode.specific.rawValue {
        didSet { objectWillChange.send() }
    }
    public var targetAppMode: TargetAppMode {
        get { TargetAppMode(rawValue: targetAppModeRaw) ?? .specific }
        set { targetAppModeRaw = newValue.rawValue }
    }
    
    @AppStorage("targetAppName") public var targetAppName: String = "Minecraft" {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("targetAppBundleId") public var targetAppBundleId: String = "" {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("ratioMode") public var ratioModeRaw: String = RatioMode.clicksPerScroll.rawValue {
        didSet { objectWillChange.send() }
    }
    public var ratioMode: RatioMode {
        get { RatioMode(rawValue: ratioModeRaw) ?? .clicksPerScroll }
        set { ratioModeRaw = newValue.rawValue }
    }
    
    @AppStorage("clicksPerScroll") public var clicksPerScroll: Int = 1 {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("scrollsPerClick") public var scrollsPerClick: Int = 2 {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("clickDelayMs") public var clickDelayMs: Int = 5 {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("scrollDirection") public var scrollDirectionRaw: String = ScrollDirectionOption.both.rawValue {
        didSet { objectWillChange.send() }
    }
    public var scrollDirection: ScrollDirectionOption {
        get { ScrollDirectionOption(rawValue: scrollDirectionRaw) ?? .both }
        set { scrollDirectionRaw = newValue.rawValue }
    }
    
    @AppStorage("mouseButton") public var mouseButtonRaw: String = MouseButtonOption.left.rawValue {
        didSet { objectWillChange.send() }
    }
    public var mouseButton: MouseButtonOption {
        get { MouseButtonOption(rawValue: mouseButtonRaw) ?? .left }
        set { mouseButtonRaw = newValue.rawValue }
    }
    
    @AppStorage("suppressOriginalScroll") public var suppressOriginalScroll: Bool = true {
        didSet { objectWillChange.send() }
    }

    @Published public var isShowingAppPicker: Bool = false
    @Published public var testClickCount: Int = 0

    private init() {}
}

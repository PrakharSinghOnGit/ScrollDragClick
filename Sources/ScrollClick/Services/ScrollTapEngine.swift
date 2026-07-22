import Foundation
import Cocoa
import CoreGraphics
import ApplicationServices

public final class ScrollTapEngine: ObservableObject {
    public static let shared = ScrollTapEngine()
    
    @Published public var isRunning: Bool = false
    @Published public var lastClickTime: Date?
    @Published public var totalClicksGenerated: Int = 0
    @Published public var statusMessage: String = "Initializing..."
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var scrollAccumulator: Int = 0
    private var retryTimer: Timer?
    
    private init() {
        startRetryTimer()
    }
    
    private func startRetryTimer() {
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if !self.isRunning && AccessibilityManager.shared.isTrusted {
                print("ScrollClick: Accessibility trusted. Retrying CGEventTap start...")
                self.start()
            }
        }
    }
    
    public func start() {
        guard !isRunning else { return }
        
        guard AccessibilityManager.shared.isTrusted else {
            DispatchQueue.main.async {
                self.statusMessage = "Waiting for Accessibility Permission..."
                self.isRunning = false
            }
            print("ScrollClick: Cannot start CGEventTap - Accessibility permission missing.")
            return
        }
        
        let eventMask: CGEventMask = (1 << CGEventType.scrollWheel.rawValue)
        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let engine = Unmanaged<ScrollTapEngine>.fromOpaque(refcon).takeUnretainedValue()
            return engine.handleEvent(proxy: proxy, type: type, event: event)
        }
        
        // Try Session Event Tap first, then HID tap as fallback
        var tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: userInfo
        )
        
        if tap == nil {
            print("ScrollClick: cgSessionEventTap failed, trying cghidEventTap...")
            tap = CGEvent.tapCreate(
                tap: .cghidEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: eventMask,
                callback: callback,
                userInfo: userInfo
            )
        }
        
        guard let validTap = tap else {
            DispatchQueue.main.async {
                self.statusMessage = "Event Tap Creation Failed (Check Accessibility)"
                self.isRunning = false
            }
            print("ScrollClick: Failed to create CGEventTap.")
            return
        }
        
        self.eventTap = validTap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, validTap, 0)
        
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            CGEvent.tapEnable(tap: validTap, enable: true)
            DispatchQueue.main.async {
                self.isRunning = true
                self.statusMessage = "Active & Intercepting Scrolls"
            }
            print("ScrollClick: CGEventTap successfully started.")
        }
    }
    
    public func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        
        eventTap = nil
        runLoopSource = nil
        
        DispatchQueue.main.async {
            self.isRunning = false
            self.statusMessage = "Stopped"
        }
        print("ScrollClick: CGEventTap stopped.")
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Auto re-enable if disabled by macOS timeout
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }
        
        guard type == .scrollWheel else {
            return Unmanaged.passUnretained(event)
        }
        
        let settings = SettingsStore.shared
        
        // 1. Master toggle check
        guard settings.isEnabled else {
            return Unmanaged.passUnretained(event)
        }
        
        // 2. Check target application matching
        let isTargetActive = AppDetector.shared.isTargetAppActive(settings: settings)
        let isScrollClickAppFront = (NSWorkspace.shared.frontmostApplication?.localizedName == "ScrollClick")
        
        // If target app isn't active AND ScrollClick settings isn't frontmost, pass event
        guard isTargetActive || isScrollClickAppFront else {
            return Unmanaged.passUnretained(event)
        }
        
        // 3. Inspect vertical and high-resolution scroll deltas
        var delta = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        if delta == 0 {
            delta = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
        }
        if delta == 0 {
            let fixedPt = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
            if fixedPt != 0 {
                delta = fixedPt > 0 ? 1 : -1
            }
        }
        // Fallback to axis 2 (horizontal/tilt wheel)
        if delta == 0 {
            delta = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        }
        
        if delta == 0 {
            // Still 0, pass event through
            return Unmanaged.passUnretained(event)
        }
        
        let isScrollUp = delta > 0
        let isScrollDown = delta < 0
        
        switch settings.scrollDirection {
        case .upOnly:
            if !isScrollUp { return Unmanaged.passUnretained(event) }
        case .downOnly:
            if !isScrollDown { return Unmanaged.passUnretained(event) }
        case .both:
            break
        }
        
        // 4. Calculate Clicks based on Ratio
        var clickCountToSend = 0
        
        switch settings.ratioMode {
        case .clicksPerScroll:
            clickCountToSend = max(1, settings.clicksPerScroll)
        case .scrollsPerClick:
            scrollAccumulator += 1
            let needed = max(1, settings.scrollsPerClick)
            if scrollAccumulator >= needed {
                clickCountToSend = 1
                scrollAccumulator = 0
            } else {
                clickCountToSend = 0
            }
        }
        
        // 5. Trigger synthetic mouse clicks
        if clickCountToSend > 0 {
            triggerMouseClicks(count: clickCountToSend, button: settings.mouseButton, delayMs: settings.clickDelayMs)
        }
        
        // 6. Suppress or pass through original scroll event
        if settings.suppressOriginalScroll {
            return nil // Absorb event
        } else {
            return Unmanaged.passUnretained(event)
        }
    }
    
    private func triggerMouseClicks(count: Int, button: MouseButtonOption, delayMs: Int) {
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            
            // Get screen cursor location
            let location = CGEvent(source: nil)?.location ?? .zero
            
            for i in 0..<count {
                self.sendSingleClick(button: button, at: location)
                
                if i < count - 1 && delayMs > 0 {
                    usleep(useconds_t(delayMs * 1000))
                }
            }
            
            DispatchQueue.main.async {
                self.lastClickTime = Date()
                self.totalClicksGenerated += count
                // Also update test click counter so test pad reflects clicks live!
                SettingsStore.shared.testClickCount += count
            }
        }
    }
    
    private func sendSingleClick(button: MouseButtonOption, at point: CGPoint) {
        let (downType, upType, cgButton): (CGEventType, CGEventType, CGMouseButton) = {
            switch button {
            case .left:
                return (.leftMouseDown, .leftMouseUp, .left)
            case .right:
                return (.rightMouseDown, .rightMouseUp, .right)
            case .middle:
                return (.otherMouseDown, .otherMouseUp, .center)
            case .button4:
                return (.otherMouseDown, .otherMouseUp, CGMouseButton(rawValue: 3)!)
            case .button5:
                return (.otherMouseDown, .otherMouseUp, CGMouseButton(rawValue: 4)!)
            }
        }()
        
        let source = CGEventSource(stateID: .hidSystemState)
        
        guard let mouseDown = CGEvent(mouseEventSource: source, mouseType: downType, mouseCursorPosition: point, mouseButton: cgButton),
              let mouseUp = CGEvent(mouseEventSource: source, mouseType: upType, mouseCursorPosition: point, mouseButton: cgButton) else {
            return
        }
        
        // Post synthetic click events to session & HID
        mouseDown.post(tap: .cgSessionEventTap)
        usleep(2000)
        mouseUp.post(tap: .cgSessionEventTap)
    }
    
    deinit {
        retryTimer?.invalidate()
    }
}

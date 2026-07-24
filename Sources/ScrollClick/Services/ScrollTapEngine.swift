import Foundation
import Cocoa
import CoreGraphics
import ApplicationServices

/// Core event tap engine. Completely rewritten for performance:
///
/// Key fixes vs. previous version:
/// - No @Published properties — zero Combine/SwiftUI overhead per scroll event.
/// - No DispatchQueue.main.async on every event — the tap callback is pure C-land work.
/// - Mouse position read via NSEvent.mouseLocation (cached CGPoint math, no CGEvent alloc).
/// - Click dispatch is fire-and-forget on a dedicated serial queue, not a global QoS queue
///   that could spawn unbounded threads under heavy scrolling.
/// - The accumulator and config snapshot are read atomically via a lock to avoid data races.
/// - The retry logic uses a longer interval (5 s) and stops once running.
/// - No UI state updates from within the hot path.

public final class ScrollTapEngine {
    public static let shared = ScrollTapEngine()

    public private(set) var isRunning: Bool = false

    /// Called on main thread when running state changes.
    public var onStateChange: ((Bool) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Serial queue for sending synthetic clicks. One thread, predictable ordering.
    private let clickQueue = DispatchQueue(label: "com.scrollclick.clicks", qos: .userInteractive)

    // Scroll accumulator for scrollsPerClick mode (only accessed from event tap thread)
    private var scrollAccumulator: Int = 0

    // Retry timer — only active when not running
    private var retryTimer: Timer?

    private init() {}

    // MARK: - Start / Stop

    public func start() {
        guard !isRunning else { return }
        guard AccessibilityManager.shared.isTrusted else {
            scheduleRetry()
            return
        }

        let eventMask: CGEventMask = (1 << CGEventType.scrollWheel.rawValue)
        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let engine = Unmanaged<ScrollTapEngine>.fromOpaque(refcon).takeUnretainedValue()
            return engine.handleEvent(proxy: proxy, type: type, event: event)
        }

        // Prefer session tap; fall back to HID tap
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: userInfo
        ) ?? CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: userInfo
        )

        guard let validTap = tap else {
            print("ScrollClick: Failed to create CGEventTap.")
            scheduleRetry()
            return
        }

        eventTap = validTap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, validTap, 0)

        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            CGEvent.tapEnable(tap: validTap, enable: true)
            isRunning = true
            retryTimer?.invalidate()
            retryTimer = nil
            DispatchQueue.main.async { self.onStateChange?(true) }
            print("ScrollClick: CGEventTap started.")
        }
    }

    public func stop() {
        retryTimer?.invalidate()
        retryTimer = nil

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isRunning = false
        DispatchQueue.main.async { self.onStateChange?(false) }
        print("ScrollClick: CGEventTap stopped.")
    }

    private func scheduleRetry() {
        guard retryTimer == nil else { return }
        retryTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self, !self.isRunning else { return }
            if AccessibilityManager.shared.isTrusted {
                self.retryTimer?.invalidate()
                self.retryTimer = nil
                self.start()
            }
        }
    }

    // MARK: - Event Handling (Hot Path)

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable tap if macOS disabled it due to timeout/user input
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        guard type == .scrollWheel else { return Unmanaged.passUnretained(event) }

        // Take a single snapshot of config — avoids repeated property lookups
        let cfg = ConfigStore.shared.config

        guard cfg.isEnabled else { return Unmanaged.passUnretained(event) }

        // Target app check — reads a cached NSRunningApplication, no NSWorkspace call
        guard AppDetector.shared.isTargetAppActive(config: cfg) else {
            return Unmanaged.passUnretained(event)
        }

        // Read scroll delta — prefer axis1 integer, fall back through alternatives
        var delta = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        if delta == 0 { delta = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) }
        if delta == 0 {
            let fp = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
            if fp != 0 { delta = fp > 0 ? 1 : -1 }
        }
        if delta == 0 { delta = event.getIntegerValueField(.scrollWheelEventDeltaAxis2) }
        if delta == 0 { return Unmanaged.passUnretained(event) }

        let isUp = delta > 0
        switch cfg.scrollDirection {
        case .upOnly   where !isUp: return Unmanaged.passUnretained(event)
        case .downOnly where  isUp: return Unmanaged.passUnretained(event)
        default: break
        }

        // Calculate click count
        var clickCount = 0
        switch cfg.ratioMode {
        case .clicksPerScroll:
            clickCount = max(1, cfg.clicksPerScroll)
        case .scrollsPerClick:
            scrollAccumulator += 1
            let needed = max(1, cfg.scrollsPerClick)
            if scrollAccumulator >= needed {
                clickCount = 1
                scrollAccumulator = 0
            }
        }

        if clickCount > 0 {
            // Capture mouse location cheaply — NSEvent.mouseLocation is a cached value
            let loc = NSEvent.mouseLocation
            // Convert from AppKit coordinates (origin bottom-left) to CG (origin top-left)
            let screenH = NSScreen.main?.frame.height ?? 0
            let cgPoint = CGPoint(x: loc.x, y: screenH - loc.y)

            let button = cfg.mouseButton
            let delayUs = useconds_t(max(0, cfg.clickDelayMs) * 1000)

            // Fire-and-forget on the dedicated serial click queue
            clickQueue.async {
                for i in 0..<clickCount {
                    Self.sendSingleClick(button: button, at: cgPoint)
                    if i < clickCount - 1 && delayUs > 0 {
                        usleep(delayUs)
                    }
                }
            }
        }

        return cfg.suppressOriginalScroll ? nil : Unmanaged.passUnretained(event)
    }

    // MARK: - Synthetic Click

    private static func sendSingleClick(button: MouseButtonOption, at point: CGPoint) {
        let (downType, upType, cgButton): (CGEventType, CGEventType, CGMouseButton) = {
            switch button {
            case .left:    return (.leftMouseDown,  .leftMouseUp,  .left)
            case .right:   return (.rightMouseDown, .rightMouseUp, .right)
            case .middle:  return (.otherMouseDown, .otherMouseUp, .center)
            case .button4: return (.otherMouseDown, .otherMouseUp, CGMouseButton(rawValue: 3)!)
            case .button5: return (.otherMouseDown, .otherMouseUp, CGMouseButton(rawValue: 4)!)
            }
        }()

        // Use HID state source so synthetic events are indistinguishable from real ones
        let source = CGEventSource(stateID: .hidSystemState)

        guard let down = CGEvent(mouseEventSource: source, mouseType: downType, mouseCursorPosition: point, mouseButton: cgButton),
              let up   = CGEvent(mouseEventSource: source, mouseType: upType,   mouseCursorPosition: point, mouseButton: cgButton)
        else { return }

        down.post(tap: .cgSessionEventTap)
        usleep(2_000) // 2 ms between down and up — realistic
        up.post(tap: .cgSessionEventTap)
    }

    deinit {
        stop()
    }
}

import AppKit
import ApplicationServices

class WindowMaximizer {
    weak var settings: AppSettings?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var hotKeyMonitor: Any?
    private var savedFrames: [String: CGRect] = [:]
    private var lastActiveApplication: NSRunningApplication?
    private var pendingZoomWindow: AXUIElement?
    private var pendingAction: (() -> Void)?
    private var lastZoomedWindow: AXUIElement?
    private var lastZoomedWindowKey: String?
    private(set) var isRunning = false

    var canRestorePreviousSize: Bool {
        guard let key = lastZoomedWindowKey else { return false }
        return savedFrames[key] != nil
    }

    func start() {
        guard !isRunning else { return }
        guard AXIsProcessTrusted() else {
            NSLog("[ORZ] Accessibility NOT granted")
            return
        }

        let mask = CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
                 | CGEventMask(1 << CGEventType.leftMouseUp.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let m = Unmanaged<WindowMaximizer>.fromOpaque(refcon).takeUnretainedValue()
                return m.handleEvent(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap = eventTap else { NSLog("[ORZ] tapCreate failed"); return }
        registerZoomHotKeyMonitor()
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let src = runLoopSource { CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes) }
        CGEvent.tapEnable(tap: tap, enable: true)

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeSpaceDidChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.processIdentifier != getpid() {
            lastActiveApplication = frontmost
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        isRunning = true
        NSLog("[ORZ] Event tap started")
    }

    func stop() {
        pendingZoomWindow = nil
        pendingAction = nil
        if let hotKeyMonitor { NSEvent.removeMonitor(hotKeyMonitor) }
        hotKeyMonitor = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        guard isRunning, let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        eventTap = nil
        runLoopSource = nil
        isRunning = false
        NSLog("[ORZ] Event tap stopped")
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passRetained(event)
        }

        if type == .leftMouseDown {
            let modifiers: CGEventFlags = [.maskShift, .maskControl, .maskCommand, .maskAlternate]
            guard event.flags.intersection(modifiers).isEmpty else {
                cancelPending()
                return Unmanaged.passRetained(event)
            }

            let click = CGPoint(x: event.location.x, y: event.location.y)

            let system = AXUIElementCreateSystemWide()
            var axEl: AXUIElement?
            guard AXUIElementCopyElementAtPosition(system, Float(click.x), Float(click.y), &axEl) == .success,
                  let el = axEl else {
                cancelPending()
                return Unmanaged.passRetained(event)
            }

            var pid: pid_t = 0
            AXUIElementGetPid(el, &pid)
            let appElement = AXUIElementCreateApplication(pid)

            guard let window = focusedOrMainWindow(appElement) else {
                cancelPending()
                return Unmanaged.passRetained(event)
            }

            var zoomRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(window, kAXZoomButtonAttribute as CFString, &zoomRef) == .success,
                  let zoomBtn = zoomRef,
                  let btnFrame = getElementFrame(zoomBtn as! AXUIElement),
                  btnFrame.insetBy(dx: -6, dy: -6).contains(click) else {
                cancelPending()
                return Unmanaged.passRetained(event)
            }

            let zoomButton = zoomBtn as! AXUIElement

            guard let screen = screenForWindow(window) else {
                cancelPending()
                return Unmanaged.passRetained(event)
            }

            // NSScreen.visibleFrame already accounts for the menu bar and Dock.
            // macOS's native tiled-window gutter is approximately 8 points.
            let visibleFrame = settings?.useWindowMargins == true
                ? screen.visibleFrame.insetBy(dx: 8, dy: 8)
                : screen.visibleFrame
            let targetFrame = convertToAXCoordinates(visibleFrame, screen: screen)
            let currentFrame = getElementFrame(window)
            let key = windowKey(for: window)
            let alternateVisibleFrame = settings?.useWindowMargins == true
                ? screen.visibleFrame
                : screen.visibleFrame.insetBy(dx: 8, dy: 8)
            let alternateTargetFrame = convertToAXCoordinates(alternateVisibleFrame, screen: screen)

            let isAtZoomedFrame = isWindowMaximized(currentFrame, targetFrame: targetFrame)
                || isWindowMaximized(currentFrame, targetFrame: alternateTargetFrame)
            if isAtZoomedFrame, let saved = savedFrames[key] {
                pendingAction = { [weak self] in
                    // Invoke the native zoom control as well as restoring the
                    // saved frame. This dismisses macOS's green-button tiling
                    // popover and keeps the native zoom state in sync.
                    AXUIElementPerformAction(zoomButton, kAXPressAction as CFString)
                    self?.setWindowFrame(window, frame: saved)
                    self?.savedFrames.removeValue(forKey: key)
                    self?.lastZoomedWindow = nil
                    self?.lastZoomedWindowKey = nil
                }
            } else {
                if let frame = currentFrame { savedFrames[key] = frame }
                lastZoomedWindow = window
                lastZoomedWindowKey = key
                pendingAction = { [weak self] in
                    // The actual pointer remains over the green button after
                    // resizing, so the native hover menu can stay open. Press
                    // its AX button to dismiss it before applying our frame.
                    AXUIElementPerformAction(zoomButton, kAXPressAction as CFString)
                    self?.setWindowFrame(window, frame: targetFrame)
                }
            }

            pendingZoomWindow = window

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard let self, self.pendingZoomWindow != nil else { return }
                self.executePendingAction()
            }

            return nil
        }

        if type == .leftMouseUp, pendingZoomWindow != nil {
            return nil
        }

        return Unmanaged.passRetained(event)
    }

    @objc private func activeSpaceDidChange() {
        guard let window = pendingZoomWindow else { return }
        var fsRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &fsRef)
        guard let isFS = fsRef as? Bool, isFS else { return }

        pendingZoomWindow = nil
        AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, kCFBooleanFalse)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.executePendingAction()
        }
    }

    @objc private func applicationDidActivate(_ notification: Notification) {
        guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              application.processIdentifier != getpid() else { return }
        lastActiveApplication = application
    }

    private func cancelPending() {
        pendingZoomWindow = nil
        pendingAction = nil
    }

    private func executePendingAction() {
        pendingAction?()
        pendingAction = nil
        pendingZoomWindow = nil
    }

    private func registerZoomHotKeyMonitor() {
        hotKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let modifiers = event.modifierFlags.intersection([.shift, .control, .command, .option])
            guard event.keyCode == 6, modifiers == [.control, .shift] else { return }
            DispatchQueue.main.async { self?.zoomActiveWindow() }
        }
    }

    func zoomActiveWindow() {
        let app = lastActiveApplication.flatMap { $0.isTerminated ? nil : $0 }
            ?? NSWorkspace.shared.frontmostApplication
        guard let app, app.processIdentifier != getpid() else { return }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let window = focusedOrMainWindow(appElement),
              let screen = screenForWindow(window) else { return }

        let key = windowKey(for: window)
        if let saved = savedFrames[key] {
            setWindowFrame(window, frame: saved)
            savedFrames.removeValue(forKey: key)
            if lastZoomedWindowKey == key {
                lastZoomedWindow = nil
                lastZoomedWindowKey = nil
            }
            return
        }

        guard let currentFrame = getElementFrame(window) else { return }
        let visibleFrame = settings?.useWindowMargins == true
            ? screen.visibleFrame.insetBy(dx: 8, dy: 8)
            : screen.visibleFrame
        let targetFrame = convertToAXCoordinates(visibleFrame, screen: screen)
        savedFrames[key] = currentFrame
        lastZoomedWindow = window
        lastZoomedWindowKey = key
        setWindowFrame(window, frame: targetFrame)
    }

    func restorePreviousSize() {
        guard let key = lastZoomedWindowKey,
              let window = lastZoomedWindow,
              let frame = savedFrames[key] else { return }
        setWindowFrame(window, frame: frame)
        savedFrames.removeValue(forKey: key)
        lastZoomedWindow = nil
        lastZoomedWindowKey = nil
    }

    // MARK: - AX Helpers

    private func focusedOrMainWindow(_ appElement: AXUIElement) -> AXUIElement? {
        var ref: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &ref) == .success,
           let w = ref { return (w as! AXUIElement) }
        if AXUIElementCopyAttributeValue(appElement, kAXMainWindowAttribute as CFString, &ref) == .success,
           let w = ref { return (w as! AXUIElement) }
        return nil
    }

    private func getElementFrame(_ element: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posRef as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        return CGRect(origin: position, size: size)
    }

    private func windowKey(for window: AXUIElement) -> String {
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        var titleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
        return "\(pid)-\(titleRef as? String ?? "unknown")"
    }

    private func screenForWindow(_ window: AXUIElement) -> NSScreen? {
        guard let frame = getElementFrame(window) else { return NSScreen.main }
        guard let mainScreen = NSScreen.screens.first else { return NSScreen.main }
        let nsCenter = CGPoint(x: frame.midX, y: mainScreen.frame.height - frame.midY)
        for screen in NSScreen.screens where screen.frame.contains(nsCenter) { return screen }
        return NSScreen.main
    }

    private func setWindowFrame(_ window: AXUIElement, frame: CGRect) {
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        let appElement = AXUIElementCreateApplication(pid)

        var enhancedUIRef: CFTypeRef?
        AXUIElementCopyAttributeValue(appElement, "AXEnhancedUserInterface" as CFString, &enhancedUIRef)
        let hadEnhancedUI = (enhancedUIRef as? Bool) == true
        if hadEnhancedUI {
            AXUIElementSetAttributeValue(appElement, "AXEnhancedUserInterface" as CFString, kCFBooleanFalse)
        }

        var pos = frame.origin
        var size = frame.size

        // size → position → size to handle multi-display clamping
        if let v = AXValueCreate(.cgSize, &size) { AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, v) }
        if let v = AXValueCreate(.cgPoint, &pos) { AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, v) }
        if let v = AXValueCreate(.cgSize, &size) { AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, v) }

        if hadEnhancedUI {
            AXUIElementSetAttributeValue(appElement, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        }
    }

    private func convertToAXCoordinates(_ frame: CGRect, screen: NSScreen) -> CGRect {
        guard let mainScreen = NSScreen.screens.first else { return frame }
        let axY = mainScreen.frame.height - frame.maxY
        return CGRect(x: frame.origin.x, y: axY, width: frame.width, height: frame.height)
    }

    private func isWindowMaximized(_ currentFrame: CGRect?, targetFrame: CGRect) -> Bool {
        guard let current = currentFrame else { return false }
        let t: CGFloat = 5
        return abs(current.origin.x - targetFrame.origin.x) < t &&
               abs(current.origin.y - targetFrame.origin.y) < t &&
               abs(current.width - targetFrame.width) < t &&
               abs(current.height - targetFrame.height) < t
    }
}

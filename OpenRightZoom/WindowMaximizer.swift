import AppKit
import ApplicationServices

class WindowMaximizer {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var savedFrames: [String: CGRect] = [:]
    private var pendingZoomWindow: AXUIElement?
    private var pendingAction: (() -> Void)?
    private(set) var isRunning = false

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
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let src = runLoopSource { CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes) }
        CGEvent.tapEnable(tap: tap, enable: true)

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeSpaceDidChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )

        isRunning = true
        NSLog("[ORZ] Event tap started")
    }

    func stop() {
        pendingZoomWindow = nil
        pendingAction = nil
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

        let flags = event.flags
        let modifiers: CGEventFlags = [.maskShift, .maskControl, .maskCommand, .maskAlternate]

        if type == .leftMouseDown {
            let clickPoint = CGPoint(x: event.location.x, y: event.location.y)
            NSLog("[ORZ] mouseDown at \(clickPoint)")

            if !flags.intersection(modifiers).isEmpty {
                NSLog("[ORZ] modifier key held – passing through")
                cancelPending()
                return Unmanaged.passRetained(event)
            }

            // Step 1: find which app/PID owns the element at click position
            let system = AXUIElementCreateSystemWide()
            var axEl: AXUIElement?
            let axResult = AXUIElementCopyElementAtPosition(system, Float(clickPoint.x), Float(clickPoint.y), &axEl)
            guard axResult == .success, let el = axEl else {
                NSLog("[ORZ] AX element not found (result=\(axResult.rawValue))")
                cancelPending()
                return Unmanaged.passRetained(event)
            }
            var pid: pid_t = 0
            AXUIElementGetPid(el, &pid)
            NSLog("[ORZ] AX element found pid=\(pid)")

            // Step 2: get the window that contains this element
            let appElement = AXUIElementCreateApplication(pid)
            guard let window = focusedOrMainWindow(appElement) else {
                NSLog("[ORZ] no focused/main window for pid=\(pid)")
                cancelPending()
                return Unmanaged.passRetained(event)
            }
            NSLog("[ORZ] window found")

            // Step 3: get zoom button directly from the window via kAXZoomButtonAttribute
            var zoomRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(window, kAXZoomButtonAttribute as CFString, &zoomRef) == .success,
                  let zoomBtn = zoomRef else {
                NSLog("[ORZ] no zoom button attribute on window")
                cancelPending()
                return Unmanaged.passRetained(event)
            }
            let zoomBtnEl = zoomBtn as! AXUIElement
            NSLog("[ORZ] zoom button attribute found")

            // Step 4: verify click hits the zoom button (with tolerance)
            guard let btnFrame = getElementFrame(zoomBtnEl) else {
                NSLog("[ORZ] zoom button frame unavailable")
                cancelPending()
                return Unmanaged.passRetained(event)
            }
            let hitFrame = btnFrame.insetBy(dx: -6, dy: -6)
            NSLog("[ORZ] zoom button frame=\(btnFrame) click=\(clickPoint) hit=\(hitFrame.contains(clickPoint))")
            guard hitFrame.contains(clickPoint) else {
                cancelPending()
                return Unmanaged.passRetained(event)
            }

            guard let screen = screenForWindow(window) else {
                NSLog("[ORZ] screen not found for window")
                cancelPending()
                return Unmanaged.passRetained(event)
            }

            let targetFrame = convertToAXCoordinates(screen.visibleFrame, screen: screen)
            let currentFrame = getWindowFrame(window)
            let key = windowKey(for: window)

            if isWindowMaximized(currentFrame, targetFrame: targetFrame), let saved = savedFrames[key] {
                NSLog("[ORZ] Will restore to \(saved)")
                pendingAction = { [weak self] in
                    self?.setWindowFrame(window, frame: saved)
                    self?.savedFrames.removeValue(forKey: key)
                }
            } else {
                if let frame = currentFrame { savedFrames[key] = frame }
                NSLog("[ORZ] Will maximize to \(targetFrame)")
                pendingAction = { [weak self] in
                    self?.setWindowFrame(window, frame: targetFrame)
                }
            }

            pendingZoomWindow = window

            // Fallback: if no space change occurs within 0.35s, fullscreen was blocked → apply directly
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard let self, self.pendingZoomWindow != nil else { return }
                NSLog("[ORZ] No fullscreen detected – applying action directly")
                self.executePendingAction()
            }

            return nil // consume mouseDown
        }

        if type == .leftMouseUp, pendingZoomWindow != nil {
            return nil // consume mouseUp
        }

        return Unmanaged.passRetained(event)
    }

    @objc private func activeSpaceDidChange() {
        guard let window = pendingZoomWindow else { return }
        var fsRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &fsRef)
        guard let isFS = fsRef as? Bool, isFS else { return }

        NSLog("[ORZ] Fullscreen detected via space change – cancelling, will apply after exit animation")
        pendingZoomWindow = nil  // prevent the 0.35s fallback from firing
        AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, kCFBooleanFalse)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.executePendingAction()
        }
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
        guard let frame = getWindowFrame(window) else { return NSScreen.main }
        guard let mainScreen = NSScreen.screens.first else { return NSScreen.main }
        let nsCenter = CGPoint(x: frame.midX, y: mainScreen.frame.height - frame.midY)
        for screen in NSScreen.screens where screen.frame.contains(nsCenter) { return screen }
        return NSScreen.main
    }

    private func getWindowFrame(_ window: AXUIElement) -> CGRect? {
        return getElementFrame(window)
    }

    private func setWindowFrame(_ window: AXUIElement, frame: CGRect) {
        // Get the application element to handle AXEnhancedUserInterface (Electron/Java apps)
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        let appElement = AXUIElementCreateApplication(pid)

        // Disable AXEnhancedUserInterface if set — it silently blocks position/size writes
        var enhancedUIRef: CFTypeRef?
        AXUIElementCopyAttributeValue(appElement, "AXEnhancedUserInterface" as CFString, &enhancedUIRef)
        let hadEnhancedUI = (enhancedUIRef as? Bool) == true
        if hadEnhancedUI {
            NSLog("[ORZ] Disabling AXEnhancedUserInterface")
            AXUIElementSetAttributeValue(appElement, "AXEnhancedUserInterface" as CFString, kCFBooleanFalse)
        }

        var pos = frame.origin
        var size = frame.size

        // Rectangle's proven sequence: size → position → size
        // (fixes multi-display clamping: macOS enforces sizes that fit the current display)
        if let v = AXValueCreate(.cgSize, &size) {
            let err = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, v)
            NSLog("[ORZ] set size=\(size) err=\(err.rawValue)")
        }
        if let v = AXValueCreate(.cgPoint, &pos) {
            let err = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, v)
            NSLog("[ORZ] set pos=\(pos) err=\(err.rawValue)")
        }
        if let v = AXValueCreate(.cgSize, &size) {
            let err = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, v)
            NSLog("[ORZ] set size(2nd)=\(size) err=\(err.rawValue)")
        }

        // Restore AXEnhancedUserInterface if we disabled it
        if hadEnhancedUI {
            AXUIElementSetAttributeValue(appElement, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        }

        // Log actual result to detect silent failures
        if let actual = getWindowFrame(window) {
            NSLog("[ORZ] actual frame after set: \(actual)")
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

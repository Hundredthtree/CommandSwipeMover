import AppKit
import ApplicationServices
import CoreGraphics
import Darwin
import Foundation

enum SwipeDirection: String {
    case left
    case right
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusController = StatusController()
    private let windowMover = WindowMover()
    private let whatsAppOverlayController = WhatsAppOverlayController()
    private let braveController = BraveController()
    private let gestureController = GestureController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let requestAccessibility = {
            _ = AccessibilityPermission.request()
            _ = InputMonitoringPermission.request()
            self.gestureController.refreshPermissions()
            self.refreshPermissions()
        }

        let moveLeft = {
            self.moveFrontmostWindow(.left)
        }

        let moveRight = {
            self.moveFrontmostWindow(.right)
        }

        let toggleWhatsApp = {
            self.toggleWhatsAppOverlay()
        }

        let openBrave = {
            self.openBraveBrowser()
        }

        let quit = {
            NSApp.terminate(nil)
        }

        statusController.onRequestAccessibility = requestAccessibility
        statusController.onMoveLeft = moveLeft
        statusController.onMoveRight = moveRight
        statusController.onToggleWhatsApp = toggleWhatsApp
        statusController.onOpenBrave = openBrave
        statusController.onQuit = quit

        gestureController.onSwipe = { direction in
            self.moveFrontmostWindow(direction)
        }
        gestureController.onThreeFingerSwipeDown = {
            self.toggleWhatsAppOverlay()
        }
        gestureController.onCommandThreeFingerSwipeDown = {
            self.openBraveBrowser()
        }

        statusController.install()
        refreshPermissions()

        _ = AccessibilityPermission.request()
        _ = InputMonitoringPermission.request()
        gestureController.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        gestureController.stop()
    }

    private func moveFrontmostWindow(_ direction: SwipeDirection) {
        let result = windowMover.moveWindowUnderPointer(direction: direction)
        statusController.show(result.message)
    }

    private func toggleWhatsAppOverlay() {
        whatsAppOverlayController.toggle { [weak self] result in
            self?.statusController.show(result.message)
        }
    }

    private func openBraveBrowser() {
        braveController.open { [weak self] result in
            self?.statusController.show(result.message)
        }
    }

    private func refreshPermissions() {
        statusController.refresh(
            accessibilityTrusted: AccessibilityPermission.isTrusted,
            inputMonitoringTrusted: InputMonitoringPermission.isTrusted
        )
    }
}

@main
enum CommandSwipeMoverMain {
    private static let applicationDelegate = AppDelegate()

    static func main() {
        let application = NSApplication.shared
        application.delegate = applicationDelegate
        application.run()
    }
}

final class StatusController {
    var onRequestAccessibility: (() -> Void)?
    var onMoveLeft: (() -> Void)?
    var onMoveRight: (() -> Void)?
    var onToggleWhatsApp: (() -> Void)?
    var onOpenBrave: (() -> Void)?
    var onQuit: (() -> Void)?

    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let statusItem = NSMenuItem(title: "Status: Starting", action: nil, keyEquivalent: "")
    private let accessibilityItem = NSMenuItem(title: "Accessibility: Checking", action: nil, keyEquivalent: "")
    private let inputMonitoringItem = NSMenuItem(title: "Input Monitoring: Checking", action: nil, keyEquivalent: "")

    func install() {
        item.button?.image = MenuBarIcon.makeGestureIcon()
        item.button?.imagePosition = .imageOnly
        item.button?.toolTip = "CommandSwipeMover"

        let menu = NSMenu()

        let title = NSMenuItem(title: "CommandSwipeMover", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)

        statusItem.isEnabled = false
        menu.addItem(statusItem)

        accessibilityItem.isEnabled = false
        menu.addItem(accessibilityItem)

        inputMonitoringItem.isEnabled = false
        menu.addItem(inputMonitoringItem)

        menu.addItem(NSMenuItem.separator())

        let permission = NSMenuItem(
            title: "Request Permissions",
            action: #selector(requestAccessibility),
            keyEquivalent: ""
        )
        permission.target = self
        menu.addItem(permission)

        menu.addItem(NSMenuItem.separator())

        let left = NSMenuItem(title: "Move Window Under Pointer Left", action: #selector(moveLeft), keyEquivalent: "")
        left.target = self
        menu.addItem(left)

        let right = NSMenuItem(title: "Move Window Under Pointer Right", action: #selector(moveRight), keyEquivalent: "")
        right.target = self
        menu.addItem(right)

        let whatsApp = NSMenuItem(title: "Toggle WhatsApp Overlay", action: #selector(toggleWhatsApp), keyEquivalent: "")
        whatsApp.target = self
        menu.addItem(whatsApp)

        let brave = NSMenuItem(title: "Open Brave Browser", action: #selector(openBrave), keyEquivalent: "")
        brave.target = self
        menu.addItem(brave)

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        item.menu = menu
    }

    func refresh(accessibilityTrusted: Bool, inputMonitoringTrusted: Bool) {
        accessibilityItem.title = accessibilityTrusted ? "Accessibility: Enabled" : "Accessibility: Required"
        inputMonitoringItem.title = inputMonitoringTrusted ? "Input Monitoring: Enabled" : "Input Monitoring: Required"
        show("Command + three-finger left/right moves windows. Command + down opens Brave. Three-finger down toggles WhatsApp.")
    }

    func show(_ message: String) {
        statusItem.title = "Status: \(message)"
    }

    @objc private func requestAccessibility() {
        onRequestAccessibility?()
    }

    @objc private func moveLeft() {
        onMoveLeft?()
    }

    @objc private func moveRight() {
        onMoveRight?()
    }

    @objc private func toggleWhatsApp() {
        onToggleWhatsApp?()
    }

    @objc private func openBrave() {
        onOpenBrave?()
    }

    @objc private func quit() {
        onQuit?()
    }
}

enum MenuBarIcon {
    static func makeGestureIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)

        image.lockFocus()
        defer {
            image.unlockFocus()
            image.isTemplate = true
        }

        NSColor.black.setStroke()
        NSColor.black.setFill()

        for x in [4.0, 8.0, 12.0] as [CGFloat] {
            NSBezierPath(
                roundedRect: NSRect(x: x, y: 10.2, width: 2.2, height: 5.6),
                xRadius: 1.1,
                yRadius: 1.1
            ).fill()
        }

        let swipe = NSBezierPath()
        swipe.lineWidth = 1.9
        swipe.lineCapStyle = .round
        swipe.lineJoinStyle = .round
        swipe.move(to: NSPoint(x: 3.6, y: 5.8))
        swipe.line(to: NSPoint(x: 14.4, y: 5.8))
        swipe.stroke()

        let leftHead = NSBezierPath()
        leftHead.lineWidth = 1.9
        leftHead.lineCapStyle = .round
        leftHead.lineJoinStyle = .round
        leftHead.move(to: NSPoint(x: 6.0, y: 8.0))
        leftHead.line(to: NSPoint(x: 3.6, y: 5.8))
        leftHead.line(to: NSPoint(x: 6.0, y: 3.6))
        leftHead.stroke()

        let rightHead = NSBezierPath()
        rightHead.lineWidth = 1.9
        rightHead.lineCapStyle = .round
        rightHead.lineJoinStyle = .round
        rightHead.move(to: NSPoint(x: 12.0, y: 8.0))
        rightHead.line(to: NSPoint(x: 14.4, y: 5.8))
        rightHead.line(to: NSPoint(x: 12.0, y: 3.6))
        rightHead.stroke()

        return image
    }
}

enum AccessibilityPermission {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func request() -> Bool {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

enum InputMonitoringPermission {
    static var isTrusted: Bool {
        CGPreflightListenEventAccess()
    }

    @discardableResult
    static func request() -> Bool {
        if CGPreflightListenEventAccess() {
            return true
        }
        return CGRequestListenEventAccess()
    }
}

struct MoveResult {
    let message: String
}

final class WindowMover {
    private let ownProcessIdentifier = NSRunningApplication.current.processIdentifier

    func moveWindowUnderPointer(direction: SwipeDirection) -> MoveResult {
        guard AccessibilityPermission.isTrusted else {
            return MoveResult(message: "Accessibility permission required.")
        }

        guard let target = targetWindowUnderPointer() else {
            return MoveResult(message: "No window under pointer.")
        }

        guard let app = NSRunningApplication(processIdentifier: target.ownerPID) else {
            return MoveResult(message: "Could not identify app under pointer.")
        }

        let window = target.window

        clearMinimizedState(window)

        guard let frame = windowFrame(window) else {
            return MoveResult(message: "Could not read current window frame.")
        }

        let displays = activeDisplays()
        guard displays.count > 1 else {
            return MoveResult(message: "Only one display is connected.")
        }

        guard let destinationDisplay = targetDisplay(for: frame, direction: direction, displays: displays) else {
            return MoveResult(message: "Could not choose target display.")
        }

        let targetFrame = destinationDisplay.bounds
        let position = CGPoint(x: targetFrame.minX, y: targetFrame.minY)
        let size = CGSize(width: targetFrame.width, height: targetFrame.height)

        let positionError = setAXValue(window, attribute: kAXPositionAttribute, point: position)
        let sizeError = setAXValue(window, attribute: kAXSizeAttribute, size: size)

        guard positionError == .success, sizeError == .success else {
            return MoveResult(message: "Move failed: \(describe(positionError)), \(describe(sizeError)).")
        }

        focusMovedWindow(window, ownerPID: target.ownerPID, runningApp: app)

        let appName = app.localizedName ?? "Window"
        return MoveResult(message: "\(appName) moved \(direction.rawValue).")
    }

    private struct WindowCandidate {
        let ownerPID: pid_t
        let windowNumber: CGWindowID
        let bounds: CGRect
        let title: String?
    }

    private struct TargetWindow {
        let ownerPID: pid_t
        let window: AXUIElement
    }

    private func targetWindowUnderPointer() -> TargetWindow? {
        let pointer = currentPointerLocation()

        if let target = accessibilityWindow(at: pointer) {
            return target
        }

        guard let candidate = topWindowCandidate(at: pointer) else {
            return nil
        }

        let axApp = AXUIElementCreateApplication(candidate.ownerPID)
        guard let window = matchingWindow(for: axApp, candidate: candidate) else {
            return nil
        }

        return TargetWindow(ownerPID: candidate.ownerPID, window: window)
    }

    private func currentPointerLocation() -> CGPoint {
        guard let event = CGEvent(source: nil) else {
            return .zero
        }
        return event.location
    }

    private func accessibilityWindow(at point: CGPoint) -> TargetWindow? {
        let systemWide = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        let error = AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &element)

        guard error == .success,
              let element,
              let window = containingWindow(for: element),
              let ownerPID = processIdentifier(for: window) ?? processIdentifier(for: element),
              ownerPID != ownProcessIdentifier else {
            return nil
        }

        return TargetWindow(ownerPID: ownerPID, window: window)
    }

    private func containingWindow(for element: AXUIElement) -> AXUIElement? {
        if role(of: element) == kAXWindowRole {
            return element
        }

        if let window = accessibilityElementAttribute(kAXWindowAttribute, element: element) {
            return window
        }

        var current = element
        for _ in 0..<8 {
            guard let parent = accessibilityElementAttribute(kAXParentAttribute, element: current) else {
                return nil
            }

            if role(of: parent) == kAXWindowRole {
                return parent
            }

            if let window = accessibilityElementAttribute(kAXWindowAttribute, element: parent) {
                return window
            }

            current = parent
        }

        return nil
    }

    private func accessibilityElementAttribute(_ attribute: String, element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return (value as! AXUIElement)
    }

    private func role(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value) == .success,
              let value else {
            return nil
        }
        return value as? String
    }

    private func processIdentifier(for element: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else {
            return nil
        }
        return pid
    }

    private func topWindowCandidate(at point: CGPoint) -> WindowCandidate? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let rawWindows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for info in rawWindows {
            guard let layer = intValue(info[kCGWindowLayer as String]), layer == 0 else {
                continue
            }
            guard let ownerPIDValue = intValue(info[kCGWindowOwnerPID as String]),
                  ownerPIDValue != Int(ownProcessIdentifier) else {
                continue
            }
            guard let alpha = doubleValue(info[kCGWindowAlpha as String]), alpha > 0 else {
                continue
            }
            guard let sharingState = intValue(info[kCGWindowSharingState as String]), sharingState != 0 else {
                continue
            }
            guard let boundsDictionary = info[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary),
                  bounds.width >= 40,
                  bounds.height >= 40,
                  bounds.contains(point) else {
                continue
            }
            guard let windowNumberValue = intValue(info[kCGWindowNumber as String]) else {
                continue
            }

            let title = info[kCGWindowName as String] as? String
            return WindowCandidate(
                ownerPID: pid_t(ownerPIDValue),
                windowNumber: CGWindowID(windowNumberValue),
                bounds: bounds,
                title: title
            )
        }

        return nil
    }

    private func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }
        if let value = value as? Int32 {
            return Int(value)
        }
        if let value = value as? UInt32 {
            return Int(value)
        }
        if let value = value as? NSNumber {
            return value.intValue
        }
        return nil
    }

    private func doubleValue(_ value: Any?) -> Double? {
        if let value = value as? Double {
            return value
        }
        if let value = value as? CGFloat {
            return Double(value)
        }
        if let value = value as? NSNumber {
            return value.doubleValue
        }
        return nil
    }

    private func matchingWindow(for axApp: AXUIElement, candidate: WindowCandidate) -> AXUIElement? {
        guard let windows = appWindows(for: axApp) else {
            return nil
        }

        if let exactByNumber = windows.first(where: { window in
            AccessibilityValue.windowNumberAttribute(window) == Int(candidate.windowNumber)
        }) {
            return exactByNumber
        }

        if let bestByFrame = windows
            .map({ window -> (window: AXUIElement, score: CGFloat) in
                let frame = windowFrame(window) ?? .null
                return (window, frame.intersection(candidate.bounds).area)
            })
            .filter({ $0.score > 0 })
            .max(by: { $0.score < $1.score }) {
            return bestByFrame.window
        }

        return nil
    }

    private func appWindows(for axApp: AXUIElement) -> [AXUIElement]? {
        var windowsValue: CFTypeRef?
        let windowsError = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsValue)
        guard windowsError == .success, let windows = windowsValue as? [AXUIElement] else {
            return nil
        }
        return windows
    }

    private func focusedWindow(for axApp: AXUIElement) -> AXUIElement? {
        var focused: CFTypeRef?
        let focusedError = AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focused)
        if focusedError == .success, let focused {
            return (focused as! AXUIElement)
        }

        guard let windows = appWindows(for: axApp) else {
            return nil
        }
        return windows.first
    }

    private func clearMinimizedState(_ window: AXUIElement) {
        var minimized = false
        if let value = AccessibilityValue.boolAttribute(kAXMinimizedAttribute, element: window) {
            minimized = value
        }
        if minimized {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
    }

    private func focusMovedWindow(_ window: AXUIElement, ownerPID: pid_t, runningApp: NSRunningApplication) {
        let appElement = AXUIElementCreateApplication(ownerPID)
        _ = runningApp.activate(options: [.activateIgnoringOtherApps])
        raiseAndFocus(window, appElement: appElement)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            self.raiseAndFocus(window, appElement: appElement)
        }
    }

    private func raiseAndFocus(_ window: AXUIElement, appElement: AXUIElement) {
        _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        _ = AXUIElementSetAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, window)
        _ = AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        _ = AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    }

    private func windowFrame(_ window: AXUIElement) -> CGRect? {
        guard let position = AccessibilityValue.pointAttribute(kAXPositionAttribute, element: window),
              let size = AccessibilityValue.sizeAttribute(kAXSizeAttribute, element: window) else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    private struct Display {
        let id: CGDirectDisplayID
        let bounds: CGRect
    }

    private func activeDisplays() -> [Display] {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)

        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)

        return ids
            .prefix(Int(count))
            .map { Display(id: $0, bounds: CGDisplayBounds($0)) }
            .sorted {
                if abs($0.bounds.midX - $1.bounds.midX) > 1 {
                    return $0.bounds.midX < $1.bounds.midX
                }
                return $0.bounds.midY < $1.bounds.midY
            }
    }

    private func targetDisplay(for windowFrame: CGRect, direction: SwipeDirection, displays: [Display]) -> Display? {
        guard !displays.isEmpty else {
            return nil
        }

        let center = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        let currentIndex = displays.firstIndex { $0.bounds.contains(center) } ?? bestIntersectingDisplayIndex(for: windowFrame, displays: displays)

        guard let currentIndex else {
            return direction == .right ? displays.first : displays.last
        }

        switch direction {
        case .left:
            return displays[(currentIndex - 1 + displays.count) % displays.count]
        case .right:
            return displays[(currentIndex + 1) % displays.count]
        }
    }

    private func bestIntersectingDisplayIndex(for windowFrame: CGRect, displays: [Display]) -> Int? {
        displays.indices.max { lhs, rhs in
            let lhsArea = windowFrame.intersection(displays[lhs].bounds).area
            let rhsArea = windowFrame.intersection(displays[rhs].bounds).area
            return lhsArea < rhsArea
        }
    }

    private func setAXValue(_ element: AXUIElement, attribute: String, point: CGPoint) -> AXError {
        var mutablePoint = point
        guard let value = AXValueCreate(.cgPoint, &mutablePoint) else {
            return .failure
        }
        return AXUIElementSetAttributeValue(element, attribute as CFString, value)
    }

    private func setAXValue(_ element: AXUIElement, attribute: String, size: CGSize) -> AXError {
        var mutableSize = size
        guard let value = AXValueCreate(.cgSize, &mutableSize) else {
            return .failure
        }
        return AXUIElementSetAttributeValue(element, attribute as CFString, value)
    }

    private func describe(_ error: AXError) -> String {
        switch error {
        case .success:
            return "success"
        case .failure:
            return "failure"
        case .illegalArgument:
            return "illegal argument"
        case .invalidUIElement:
            return "invalid UI element"
        case .invalidUIElementObserver:
            return "invalid UI element observer"
        case .cannotComplete:
            return "cannot complete"
        case .attributeUnsupported:
            return "attribute unsupported"
        case .actionUnsupported:
            return "action unsupported"
        case .notificationUnsupported:
            return "notification unsupported"
        case .notImplemented:
            return "not implemented"
        case .notificationAlreadyRegistered:
            return "notification already registered"
        case .notificationNotRegistered:
            return "notification not registered"
        case .apiDisabled:
            return "API disabled"
        case .noValue:
            return "no value"
        case .parameterizedAttributeUnsupported:
            return "parameterized attribute unsupported"
        case .notEnoughPrecision:
            return "not enough precision"
        @unknown default:
            return "unknown"
        }
    }
}

final class WhatsAppOverlayController {
    private let bundleIdentifier = "net.whatsapp.WhatsApp"
    private let applicationURL = URL(fileURLWithPath: "/Applications/WhatsApp.app")
    private var isOverlayVisible = false
    private var isAnimating = false

    func toggle(completion: @escaping (MoveResult) -> Void) {
        guard AccessibilityPermission.isTrusted else {
            completion(MoveResult(message: "Accessibility permission required."))
            return
        }

        guard !isAnimating else {
            completion(MoveResult(message: "WhatsApp is already moving."))
            return
        }

        guard let runningApp = runningWhatsApp() else {
            showAfterLaunch(completion: completion)
            return
        }

        if !appIsHidden(runningApp),
           let window = bestWindow(for: runningApp) {
            let targetDisplay = displayContainingPointer()
            let windowOnTargetDisplay = windowIsOnDisplay(window, display: targetDisplay)
            let windowOnCurrentSpace = windowIsVisibleInCurrentSpace(window, runningApp: runningApp)

            if windowOnTargetDisplay && windowOnCurrentSpace {
                hide(window: window, runningApp: runningApp, completion: completion)
                return
            }

            if !windowOnCurrentSpace {
                show(runningApp: runningApp, completion: completion)
                return
            }

            if !windowOnTargetDisplay {
                moveVisibleWindow(window, runningApp: runningApp, to: targetDisplay, completion: completion)
                return
            }
        }

        show(runningApp: runningApp, completion: completion)
    }

    private func moveVisibleWindow(
        _ window: AXUIElement,
        runningApp: NSRunningApplication,
        to display: CGRect,
        completion: @escaping (MoveResult) -> Void
    ) {
        isAnimating = true
        clearMinimizedState(window)

        let finalFrame = overlayFrame(in: display)
        applyOverlayLayoutAndRaise(window, runningApp: runningApp, finalFrame: finalFrame)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            let visible = !self.appIsHidden(runningApp)
                && self.bestWindow(for: runningApp) != nil
                && self.windowIsVisibleInCurrentSpace(window, runningApp: runningApp)
                && self.windowIsOnDisplay(window, display: display)
            self.isOverlayVisible = visible
            self.isAnimating = false
            completion(MoveResult(message: visible ? "WhatsApp moved." : "WhatsApp could not move."))
        }
    }

    private func windowIsOnDisplay(_ window: AXUIElement, display: CGRect) -> Bool {
        guard let frame = windowFrame(window) else {
            return false
        }

        let center = CGPoint(x: frame.midX, y: frame.midY)
        return display.contains(center)
    }

    private func windowIsVisibleInCurrentSpace(_ window: AXUIElement, runningApp: NSRunningApplication) -> Bool {
        guard let targetWindowNumber = AccessibilityValue.windowNumberAttribute(window) else {
            return false
        }

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let rawWindows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        return rawWindows.contains { info in
            guard let windowNumber = windowInfoIntValue(info[kCGWindowNumber as String]),
                  windowNumber == targetWindowNumber else {
                return false
            }

            guard let ownerPID = windowInfoIntValue(info[kCGWindowOwnerPID as String]),
                  ownerPID == Int(runningApp.processIdentifier) else {
                return false
            }

            guard let alpha = windowInfoDoubleValue(info[kCGWindowAlpha as String]),
                  alpha > 0 else {
                return false
            }

            guard let sharingState = windowInfoIntValue(info[kCGWindowSharingState as String]),
                  sharingState != 0 else {
                return false
            }

            guard let boundsDictionary = info[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary) else {
                return false
            }

            return bounds.width > 40 && bounds.height > 40
        }
    }

    private func windowInfoIntValue(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }

        guard let value,
              CFGetTypeID(value as CFTypeRef) == CFNumberGetTypeID() else {
            return nil
        }

        var intValue = 0
        guard CFNumberGetValue((value as! CFNumber), .intType, &intValue) else {
            return nil
        }
        return intValue
    }

    private func windowInfoDoubleValue(_ value: Any?) -> Double? {
        if let value = value as? Double {
            return value
        }

        guard let value,
              CFGetTypeID(value as CFTypeRef) == CFNumberGetTypeID() else {
            return nil
        }

        var doubleValue = 0.0
        guard CFNumberGetValue((value as! CFNumber), .doubleType, &doubleValue) else {
            return nil
        }
        return doubleValue
    }

    private func showAfterLaunch(completion: @escaping (MoveResult) -> Void) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false

        NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration) { [weak self] app, error in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                if let app {
                    self.show(runningApp: app, completion: completion)
                    return
                }

                if let runningApp = self.runningWhatsApp() {
                    self.show(runningApp: runningApp, completion: completion)
                    return
                }

                let detail = error?.localizedDescription ?? "Could not launch WhatsApp."
                completion(MoveResult(message: detail))
            }
        }
    }

    private func show(runningApp: NSRunningApplication, completion: @escaping (MoveResult) -> Void) {
        isAnimating = true
        let display = displayContainingPointer()
        let hasExistingWindow = bestWindow(for: runningApp) != nil
        let fullScreenSpace = frontmostWindowIsFullScreen(excluding: runningApp)

        if hasExistingWindow {
            if !fullScreenSpace {
                setApplicationHidden(true, runningApp: runningApp)
            }
        } else {
            setApplicationHidden(false, runningApp: runningApp)
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration) { _, _ in }
        }

        waitForWindow(runningApp: runningApp, attemptsRemaining: 24) { [weak self] window in
            guard let self else {
                return
            }

            guard let window else {
                self.isAnimating = false
                completion(MoveResult(message: "Could not find a WhatsApp window."))
                return
            }

            self.clearMinimizedState(window)

            let finalFrame = self.overlayFrame(in: display)
            self.show(
                window: window,
                runningApp: runningApp,
                finalFrame: finalFrame,
                retryActivation: fullScreenSpace,
                completion: completion
            )
        }
    }

    private func show(
        window: AXUIElement,
        runningApp: NSRunningApplication,
        finalFrame: CGRect,
        retryActivation: Bool,
        completion: @escaping (MoveResult) -> Void
    ) {
        let applyLayoutAndRaise = {
            self.applyOverlayLayoutAndRaise(window, runningApp: runningApp, finalFrame: finalFrame)
        }

        applyLayoutAndRaise()

        if retryActivation {
            for delay in [0.18, 0.42] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    applyLayoutAndRaise()
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + (retryActivation ? 0.58 : 0.12)) {
            let visibleWindow = self.bestWindow(for: runningApp)
            let visible = !self.appIsHidden(runningApp)
                && visibleWindow != nil
                && visibleWindow.map { self.windowIsVisibleInCurrentSpace($0, runningApp: runningApp) } == true
            self.isOverlayVisible = visible
            self.isAnimating = false
            completion(MoveResult(message: visible ? "WhatsApp shown." : "WhatsApp could not come forward."))
        }
    }

    private func applyOverlayLayoutAndRaise(
        _ window: AXUIElement,
        runningApp: NSRunningApplication,
        finalFrame: CGRect
    ) {
        _ = setAXValue(window, attribute: kAXSizeAttribute, size: finalFrame.size)
        _ = setAXValue(window, attribute: kAXPositionAttribute, point: finalFrame.origin)
        _ = setWindowLevel(window, key: .floatingWindow)
        setApplicationHidden(false, runningApp: runningApp)
        raiseAndFocus(window, runningApp: runningApp)
    }

    private func hide(window: AXUIElement, runningApp: NSRunningApplication, completion: @escaping (MoveResult) -> Void) {
        isAnimating = true
        clearMinimizedState(window)
        _ = setWindowLevel(window, key: .normalWindow)
        setApplicationHidden(true, runningApp: runningApp)
        isOverlayVisible = false
        isAnimating = false
        completion(MoveResult(message: "WhatsApp hidden."))
    }

    private func runningWhatsApp() -> NSRunningApplication? {
        NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .first
    }

    private func waitForWindow(
        runningApp: NSRunningApplication,
        attemptsRemaining: Int,
        completion: @escaping (AXUIElement?) -> Void
    ) {
        if let window = bestWindow(for: runningApp) {
            completion(window)
            return
        }

        guard attemptsRemaining > 0 else {
            completion(nil)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            self.waitForWindow(
                runningApp: runningApp,
                attemptsRemaining: attemptsRemaining - 1,
                completion: completion
            )
        }
    }

    private func bestWindow(for runningApp: NSRunningApplication) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(runningApp.processIdentifier)

        var focused: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focused) == .success,
           let focused,
           CFGetTypeID(focused) == AXUIElementGetTypeID(),
           let frame = windowFrame((focused as! AXUIElement)),
           frame.width > 120,
           frame.height > 120 {
            return (focused as! AXUIElement)
        }

        guard let windows = windows(for: appElement) else {
            return nil
        }

        return windows.first { window in
            guard let frame = windowFrame(window) else {
                return false
            }
            return frame.width > 120 && frame.height > 120
        }
    }

    private func windows(for appElement: AXUIElement) -> [AXUIElement]? {
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success else {
            return nil
        }
        return windowsValue as? [AXUIElement]
    }

    private func frontmostWindowIsFullScreen(excluding runningApp: NSRunningApplication) -> Bool {
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              frontmost.processIdentifier != NSRunningApplication.current.processIdentifier,
              frontmost.processIdentifier != runningApp.processIdentifier else {
            return false
        }

        let appElement = AXUIElementCreateApplication(frontmost.processIdentifier)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focused) == .success,
              let focused,
              CFGetTypeID(focused) == AXUIElementGetTypeID() else {
            return false
        }

        return AccessibilityValue.boolAttribute("AXFullScreen", element: (focused as! AXUIElement)) == true
    }

    private func clearMinimizedState(_ window: AXUIElement) {
        if AccessibilityValue.boolAttribute(kAXMinimizedAttribute, element: window) == true {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
    }

    private func raiseAndFocus(_ window: AXUIElement, runningApp: NSRunningApplication) {
        let appElement = AXUIElementCreateApplication(runningApp.processIdentifier)
        _ = AXUIElementSetAttributeValue(appElement, "AXHidden" as CFString, kCFBooleanFalse)
        runningApp.unhide()
        runningApp.activate(options: [.activateIgnoringOtherApps])
        _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        _ = AXUIElementSetAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, window)
        _ = AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        _ = AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    }

    private func setApplicationHidden(_ hidden: Bool, runningApp: NSRunningApplication) {
        let appElement = AXUIElementCreateApplication(runningApp.processIdentifier)
        let hiddenValue: CFBoolean = hidden ? kCFBooleanTrue! : kCFBooleanFalse!
        _ = AXUIElementSetAttributeValue(appElement, "AXHidden" as CFString, hiddenValue)

        if hidden {
            runningApp.hide()
        } else {
            runningApp.unhide()
            runningApp.activate(options: [.activateIgnoringOtherApps])
        }
    }

    private func appIsHidden(_ runningApp: NSRunningApplication) -> Bool {
        let appElement = AXUIElementCreateApplication(runningApp.processIdentifier)
        return AccessibilityValue.boolAttribute("AXHidden", element: appElement) ?? runningApp.isHidden
    }

    private func windowFrame(_ window: AXUIElement) -> CGRect? {
        guard let position = AccessibilityValue.pointAttribute(kAXPositionAttribute, element: window),
              let size = AccessibilityValue.sizeAttribute(kAXSizeAttribute, element: window) else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    private func setAXValue(_ element: AXUIElement, attribute: String, point: CGPoint) -> AXError {
        var mutablePoint = point
        guard let value = AXValueCreate(.cgPoint, &mutablePoint) else {
            return .failure
        }
        return AXUIElementSetAttributeValue(element, attribute as CFString, value)
    }

    private func setAXValue(_ element: AXUIElement, attribute: String, size: CGSize) -> AXError {
        var mutableSize = size
        guard let value = AXValueCreate(.cgSize, &mutableSize) else {
            return .failure
        }
        return AXUIElementSetAttributeValue(element, attribute as CFString, value)
    }

    private func displayContainingPointer() -> CGRect {
        guard let event = CGEvent(source: nil) else {
            return mainDisplayBounds()
        }
        return displayContaining(center: event.location)
    }

    private func displayContaining(center: CGPoint) -> CGRect {
        let displays = activeDisplayBounds()
        return displays.first { $0.contains(center) } ?? mainDisplayBounds()
    }

    private func mainDisplayBounds() -> CGRect {
        let mainDisplay = CGMainDisplayID()
        return CGDisplayBounds(mainDisplay)
    }

    private func activeDisplayBounds() -> [CGRect] {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)

        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)

        return ids.prefix(Int(count)).map { CGDisplayBounds($0) }
    }

    private func overlayFrame(in display: CGRect) -> CGRect {
        let sideMargin = min(max(display.width * 0.05, 32), 80)
        let usableWidth = max(420, display.width - sideMargin * 2)
        let usableHeight = max(480, display.height - 96)
        let targetWidth = min(max(display.width * 0.42, 620), usableWidth)
        let targetHeight = min(max(display.height * 0.82, 620), usableHeight)

        return CGRect(
            x: display.minX + (display.width - targetWidth) / 2,
            y: display.minY + (display.height - targetHeight) / 2,
            width: targetWidth,
            height: targetHeight
        )
    }

    @discardableResult
    private func setWindowLevel(_ window: AXUIElement, key: CGWindowLevelKey) -> Bool {
        guard let windowNumber = AccessibilityValue.windowNumberAttribute(window) else {
            return false
        }

        return WindowLevelSetter.shared.setLevel(
            windowNumber: UInt32(windowNumber),
            level: Int32(CGWindowLevelForKey(key))
        )
    }
}

final class BraveController {
    private let bundleIdentifier = "com.brave.Browser"
    private let applicationURL = URL(fileURLWithPath: "/Applications/Brave Browser.app")

    func open(completion: @escaping (MoveResult) -> Void) {
        if let runningApp = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .first {
            runningApp.unhide()
            runningApp.activate(options: [.activateIgnoringOtherApps])
            completion(MoveResult(message: "Brave opened."))
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration) { app, error in
            DispatchQueue.main.async {
                if let app {
                    app.unhide()
                    app.activate(options: [.activateIgnoringOtherApps])
                    completion(MoveResult(message: "Brave opened."))
                    return
                }

                completion(MoveResult(message: error?.localizedDescription ?? "Could not open Brave."))
            }
        }
    }
}

final class WindowLevelSetter {
    static let shared = WindowLevelSetter()

    private typealias CGSMainConnectionIDFunction = @convention(c) () -> UInt32
    private typealias CGSSetWindowLevelFunction = @convention(c) (UInt32, UInt32, Int32) -> Int32

    private let mainConnectionID: CGSMainConnectionIDFunction?
    private let setWindowLevel: CGSSetWindowLevelFunction?

    private init() {
        let frameworkPath = "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics"
        let handle = dlopen(frameworkPath, RTLD_NOW) ?? dlopen(nil, RTLD_NOW)

        if let handle,
           let connectionSymbol = dlsym(handle, "CGSMainConnectionID"),
           let setLevelSymbol = dlsym(handle, "CGSSetWindowLevel") {
            mainConnectionID = unsafeBitCast(connectionSymbol, to: CGSMainConnectionIDFunction.self)
            setWindowLevel = unsafeBitCast(setLevelSymbol, to: CGSSetWindowLevelFunction.self)
        } else {
            mainConnectionID = nil
            setWindowLevel = nil
        }
    }

    func setLevel(windowNumber: UInt32, level: Int32) -> Bool {
        guard let mainConnectionID, let setWindowLevel else {
            return false
        }

        let result = setWindowLevel(mainConnectionID(), windowNumber, level)
        return result == 0
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull, !isEmpty else {
            return 0
        }
        return width * height
    }
}

private enum AccessibilityValue {
    static func pointAttribute(_ attribute: String, element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let axValue = value,
              CFGetTypeID(axValue) == AXValueGetTypeID() else {
            return nil
        }

        var point = CGPoint.zero
        guard AXValueGetValue((axValue as! AXValue), .cgPoint, &point) else {
            return nil
        }
        return point
    }

    static func sizeAttribute(_ attribute: String, element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let axValue = value,
              CFGetTypeID(axValue) == AXValueGetTypeID() else {
            return nil
        }

        var size = CGSize.zero
        guard AXValueGetValue((axValue as! AXValue), .cgSize, &size) else {
            return nil
        }
        return size
    }

    static func boolAttribute(_ attribute: String, element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value else {
            return nil
        }
        return CFBooleanGetValue((value as! CFBoolean))
    }

    static func intAttribute(_ attribute: String, element: AXUIElement) -> Int? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value else {
            return nil
        }

        if CFGetTypeID(value) == CFNumberGetTypeID() {
            var intValue = 0
            guard CFNumberGetValue((value as! CFNumber), .intType, &intValue) else {
                return nil
            }
            return intValue
        }

        return nil
    }

    static func windowNumberAttribute(_ element: AXUIElement) -> Int? {
        intAttribute("AXWindowNumber", element: element)
    }
}

final class GestureController {
    var onSwipe: ((SwipeDirection) -> Void)?
    var onThreeFingerSwipeDown: (() -> Void)?
    var onCommandThreeFingerSwipeDown: (() -> Void)?

    private var framework: MultitouchFramework?
    private let systemGestureSuppressor = SystemGestureSuppressor()

    func start() {
        GestureEngine.shared.onSwipe = { [weak self] direction in
            DispatchQueue.main.async {
                self?.onSwipe?(direction)
            }
        }
        GestureEngine.shared.onSwipeDown = { [weak self] in
            DispatchQueue.main.async {
                self?.onThreeFingerSwipeDown?()
            }
        }
        GestureEngine.shared.onCommandSwipeDown = { [weak self] in
            DispatchQueue.main.async {
                self?.onCommandThreeFingerSwipeDown?()
            }
        }

        systemGestureSuppressor.start()

        do {
            framework = try MultitouchFramework()
            try framework?.start()
        } catch {
            NSLog("CommandSwipeMover gesture start failed: \(error.localizedDescription)")
        }
    }

    func stop() {
        systemGestureSuppressor.stop()
        framework?.stop()
        framework = nil
    }

    func refreshPermissions() {
        systemGestureSuppressor.start()
    }
}

final class SystemGestureSuppressor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func start() {
        stop()

        guard InputMonitoringPermission.isTrusted else {
            NSLog("CommandSwipeMover system gesture suppression needs Input Monitoring permission.")
            return
        }

        let eventTypes: [UInt32] = [
            UInt32(CGEventType.flagsChanged.rawValue),
            UInt32(CGEventType.scrollWheel.rawValue),
            18, // NSEventTypeRotate
            19, // NSEventTypeBeginGesture
            20, // NSEventTypeEndGesture
            29, // NSEventTypeGesture
            30, // NSEventTypeMagnify
            31, // NSEventTypeSwipe
            32  // NSEventTypeSmartMagnify
        ]

        let mask = eventTypes.reduce(CGEventMask(0)) { partial, type in
            partial | (CGEventMask(1) << type)
        }

        let context = Unmanaged.passUnretained(self).toOpaque()
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: systemGestureEventTapCallback,
            userInfo: context
        ) ?? CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: systemGestureEventTapCallback,
            userInfo: context
        )

        guard let eventTap else {
            NSLog("CommandSwipeMover could not create event tap for system gesture suppression.")
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
            NSLog("CommandSwipeMover could not create event tap run loop source.")
            return
        }

        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, CFRunLoopMode.commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, CFRunLoopMode.commonModes)
        }

        eventTap = nil
        runLoopSource = nil
    }

    fileprivate func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let eventCommandDown = event.flags.contains(.maskCommand)
        if type == .flagsChanged {
            GestureEngine.shared.noteCommandFlagsChanged(commandDown: eventCommandDown)
            return Unmanaged.passUnretained(event)
        }

        let commandDown = eventCommandDown
            || CGEventSource.flagsState(.combinedSessionState).contains(.maskCommand)

        if GestureEngine.shared.shouldSuppressSystemGesture(type: type, commandDown: commandDown) {
            return nil
        }

        return Unmanaged.passUnretained(event)
    }
}

private let systemGestureEventTapCallback: CGEventTapCallBack = { proxy, type, event, refcon in
    guard let refcon else {
        return Unmanaged.passUnretained(event)
    }

    let suppressor = Unmanaged<SystemGestureSuppressor>.fromOpaque(refcon).takeUnretainedValue()
    return suppressor.handle(proxy: proxy, type: type, event: event)
}

final class GestureEngine {
    static let shared = GestureEngine()

    var onSwipe: ((SwipeDirection) -> Void)?
    var onSwipeDown: (() -> Void)?
    var onCommandSwipeDown: (() -> Void)?

    private enum CaptureMode {
        case commandHorizontal
        case bareVertical
    }

    private let lock = NSLock()
    private var startCentroid: CGPoint?
    private var captureMode: CaptureMode?
    private var isCapturingCommandThreeFingerGesture = false
    private var isCapturingBareThreeFingerGesture = false
    private var isPassingBareThreeFingerGesture = false
    private var hasHandledBareThreeFingerContact = false
    private var hasHandledCommandThreeFingerContact = false
    private var passNextDownSwipeUntil: CFTimeInterval = 0
    private var isCommandPressed = CGEventSource.flagsState(.combinedSessionState).contains(.maskCommand)
    private var suppressUntil: CFTimeInterval = 0
    private var lastFireTime: CFTimeInterval = 0

    private let horizontalThreshold: CGFloat = 0.035
    private let verticalTolerance: CGFloat = 0.14
    private let verticalThreshold: CGFloat = 0.045
    private let horizontalTolerance: CGFloat = 0.11
    private let cooldown: CFTimeInterval = 0.18
    private let suppressionTail: CFTimeInterval = 0.7
    private let missionControlPassThroughWindow: CFTimeInterval = 1.4

    func shouldSuppressSystemGesture(type: CGEventType, commandDown: Bool) -> Bool {
        let now = CACurrentMediaTime()
        let rawType = type.rawValue
        let isHighLevelTrackpadGesture = rawType == 18
            || rawType == 19
            || rawType == 20
            || rawType == 29
            || rawType == 30
            || rawType == 31
            || rawType == 32

        lock.lock()
        let gestureSuppressionActive = isCapturingCommandThreeFingerGesture
            || now < suppressUntil
        let shouldSuppress = isHighLevelTrackpadGesture && gestureSuppressionActive
        lock.unlock()

        return shouldSuppress
    }

    func noteCommandFlagsChanged(commandDown: Bool) {
        lock.lock()
        isCommandPressed = commandDown
        if !commandDown {
            isCapturingCommandThreeFingerGesture = false
            if captureMode == .commandHorizontal {
                startCentroid = nil
                captureMode = nil
                suppressUntil = 0
            }
            hasHandledCommandThreeFingerContact = false
        }
        lock.unlock()
    }

    fileprivate func process(contacts: UnsafeMutablePointer<MTContact>?, count: Int32, timestamp: Double) -> Bool {
        guard let contacts else {
            reset()
            return false
        }

        let commandDown = commandPressed()
        guard count == 3 else {
            reset()
            return false
        }

        let centroid = Self.centroid(contacts: contacts, count: Int(count))
        let currentMode: CaptureMode = commandDown ? .commandHorizontal : .bareVertical

        lock.lock()
        defer { lock.unlock() }

        if startCentroid == nil {
            if currentMode == .bareVertical && hasHandledBareThreeFingerContact {
                return false
            }
            if currentMode == .commandHorizontal && hasHandledCommandThreeFingerContact {
                suppressUntil = CACurrentMediaTime() + suppressionTail
                return true
            }

            startCentroid = centroid
            captureMode = currentMode
            isCapturingCommandThreeFingerGesture = currentMode == .commandHorizontal
            isCapturingBareThreeFingerGesture = false
            isPassingBareThreeFingerGesture = false

            if currentMode == .commandHorizontal {
                suppressUntil = CACurrentMediaTime() + suppressionTail
                return true
            }

            suppressUntil = 0
            return false
        }

        guard let startCentroid else {
            return currentMode == .commandHorizontal
        }

        guard captureMode == currentMode else {
            self.startCentroid = centroid
            captureMode = currentMode
            isCapturingCommandThreeFingerGesture = currentMode == .commandHorizontal
            isCapturingBareThreeFingerGesture = false
            isPassingBareThreeFingerGesture = false

            if currentMode == .commandHorizontal {
                suppressUntil = CACurrentMediaTime() + suppressionTail
                return true
            }

            suppressUntil = 0
            return false
        }

        let deltaX = centroid.x - startCentroid.x
        let deltaY = centroid.y - startCentroid.y
        let now = CACurrentMediaTime()

        switch currentMode {
        case .commandHorizontal:
            isCapturingCommandThreeFingerGesture = true
            isCapturingBareThreeFingerGesture = false
            suppressUntil = now + suppressionTail

            if hasHandledCommandThreeFingerContact {
                return true
            }

            guard now - lastFireTime > cooldown else {
                return true
            }

            if deltaY <= -verticalThreshold,
               abs(deltaX) <= horizontalTolerance,
               abs(deltaY) > abs(deltaX) * 1.45 {
                hasHandledCommandThreeFingerContact = true
                lastFireTime = now
                suppressUntil = now + suppressionTail
                self.startCentroid = nil
                captureMode = nil
                onCommandSwipeDown?()
                return true
            }

            guard abs(deltaX) >= horizontalThreshold,
                  abs(deltaY) <= verticalTolerance,
                  abs(deltaX) > abs(deltaY) * 1.6 else {
                return true
            }

            lastFireTime = now
            suppressUntil = now + suppressionTail
            self.startCentroid = nil
            captureMode = nil

            let direction: SwipeDirection = deltaX < 0 ? .left : .right
            onSwipe?(direction)

        case .bareVertical:
            isCapturingCommandThreeFingerGesture = false

            if isPassingBareThreeFingerGesture {
                return false
            }

            let horizontalIntent = abs(deltaX) >= horizontalThreshold
                && abs(deltaX) > abs(deltaY) * 1.25
            if horizontalIntent {
                isPassingBareThreeFingerGesture = true
                isCapturingBareThreeFingerGesture = false
                passNextDownSwipeUntil = 0
                suppressUntil = 0
                return false
            }

            let upwardIntent = deltaY >= verticalThreshold
                && abs(deltaY) > abs(deltaX) * 1.25
            if upwardIntent {
                passNextDownSwipeUntil = now + missionControlPassThroughWindow
                isPassingBareThreeFingerGesture = true
                isCapturingBareThreeFingerGesture = false
                suppressUntil = 0
                return false
            }

            guard now - lastFireTime > cooldown else {
                return false
            }

            guard deltaY <= -verticalThreshold,
                  abs(deltaX) <= horizontalTolerance,
                  abs(deltaY) > abs(deltaX) * 1.45 else {
                return false
            }

            if now < passNextDownSwipeUntil {
                passNextDownSwipeUntil = 0
                isPassingBareThreeFingerGesture = true
                isCapturingBareThreeFingerGesture = false
                suppressUntil = 0
                return false
            }

            passNextDownSwipeUntil = 0
            isCapturingBareThreeFingerGesture = false
            isPassingBareThreeFingerGesture = true
            lastFireTime = now
            suppressUntil = 0
            self.startCentroid = nil
            captureMode = nil

            onSwipeDown?()
            hasHandledBareThreeFingerContact = true
            return false
        }

        return true
    }

    private func commandPressed() -> Bool {
        lock.lock()
        let commandDown = isCommandPressed
        lock.unlock()
        return commandDown
    }

    private func reset(keepSuppression: Bool = true) {
        lock.lock()
        if keepSuppression && (isCapturingCommandThreeFingerGesture || isCapturingBareThreeFingerGesture) {
            suppressUntil = CACurrentMediaTime() + suppressionTail
        }
        isCapturingCommandThreeFingerGesture = false
        isCapturingBareThreeFingerGesture = false
        isPassingBareThreeFingerGesture = false
        hasHandledBareThreeFingerContact = false
        hasHandledCommandThreeFingerContact = false
        if CACurrentMediaTime() >= passNextDownSwipeUntil {
            passNextDownSwipeUntil = 0
        }
        startCentroid = nil
        captureMode = nil
        lock.unlock()
    }

    private static func centroid(contacts: UnsafeMutablePointer<MTContact>, count: Int) -> CGPoint {
        var x: CGFloat = 0
        var y: CGFloat = 0

        for index in 0..<count {
            let position = contacts[index].normalized.position
            x += CGFloat(position.x)
            y += CGFloat(position.y)
        }

        let divisor = CGFloat(max(count, 1))
        return CGPoint(x: x / divisor, y: y / divisor)
    }
}

fileprivate typealias MTDeviceRef = UnsafeMutableRawPointer
fileprivate typealias MTContactCallback = @convention(c) (MTDeviceRef?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32
fileprivate typealias MTDeviceCreateListFunction = @convention(c) () -> CFArray
fileprivate typealias MTRegisterContactFrameCallbackFunction = @convention(c) (MTDeviceRef?, MTContactCallback?) -> Void
fileprivate typealias MTUnregisterContactFrameCallbackFunction = @convention(c) (MTDeviceRef?, MTContactCallback?) -> Void
fileprivate typealias MTDeviceStartFunction = @convention(c) (MTDeviceRef?, Int32) -> Void
fileprivate typealias MTDeviceStopFunction = @convention(c) (MTDeviceRef?) -> Void

fileprivate struct MTPoint {
    var x: Float
    var y: Float
}

fileprivate struct MTReadout {
    var position: MTPoint
    var velocity: MTPoint
}

fileprivate struct MTContact {
    var frame: Int32
    var timestamp: Double
    var identifier: Int32
    var state: Int32
    var fingerID: Int32
    var handID: Int32
    var normalized: MTReadout
    var size: Float
    var zero1: Int32
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var mm: MTReadout
    var zero2a: Int32
    var zero2b: Int32
    var unknown: Float
}

private let multitouchContactCallback: MTContactCallback = { _, contacts, count, timestamp, _ in
    let typedContacts = contacts?.assumingMemoryBound(to: MTContact.self)
    let shouldSuppress = GestureEngine.shared.process(contacts: typedContacts, count: count, timestamp: timestamp)
    return shouldSuppress ? 1 : 0
}

enum MultitouchError: LocalizedError {
    case frameworkUnavailable
    case symbolMissing(String)
    case noDevices

    var errorDescription: String? {
        switch self {
        case .frameworkUnavailable:
            return "Could not load MultitouchSupport.framework."
        case .symbolMissing(let symbol):
            return "Could not load \(symbol)."
        case .noDevices:
            return "No multitouch devices found."
        }
    }
}

final class MultitouchFramework {
    private let handle: UnsafeMutableRawPointer
    private let createList: MTDeviceCreateListFunction
    private let registerCallback: MTRegisterContactFrameCallbackFunction
    private let unregisterCallback: MTUnregisterContactFrameCallbackFunction?
    private let deviceStart: MTDeviceStartFunction
    private let deviceStop: MTDeviceStopFunction
    private var devices: [MTDeviceRef] = []
    private var isRunning = false

    init() throws {
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let handle = dlopen(path, RTLD_NOW) else {
            throw MultitouchError.frameworkUnavailable
        }

        self.handle = handle
        self.createList = try Self.load("MTDeviceCreateList", from: handle)
        self.registerCallback = try Self.load("MTRegisterContactFrameCallback", from: handle)
        self.unregisterCallback = Self.loadOptional("MTUnregisterContactFrameCallback", from: handle) as MTUnregisterContactFrameCallbackFunction?
        self.deviceStart = try Self.load("MTDeviceStart", from: handle)
        self.deviceStop = try Self.load("MTDeviceStop", from: handle)
    }

    deinit {
        stop()
        dlclose(handle)
    }

    func start() throws {
        guard !isRunning else {
            return
        }

        let list = createList()
        let count = CFArrayGetCount(list)
        guard count > 0 else {
            throw MultitouchError.noDevices
        }

        devices = (0..<count).compactMap { index in
            guard let pointer = CFArrayGetValueAtIndex(list, index) else {
                return nil
            }
            return MTDeviceRef(mutating: pointer)
        }

        for device in devices {
            registerCallback(device, multitouchContactCallback)
            deviceStart(device, 0)
        }

        isRunning = true
    }

    func stop() {
        guard isRunning else {
            return
        }

        for device in devices {
            if let unregisterCallback {
                unregisterCallback(device, multitouchContactCallback)
            }
            deviceStop(device)
        }

        devices.removeAll()
        isRunning = false
    }

    private static func load<T>(_ symbol: String, from handle: UnsafeMutableRawPointer) throws -> T {
        guard let pointer = dlsym(handle, symbol) else {
            throw MultitouchError.symbolMissing(symbol)
        }
        return unsafeBitCast(pointer, to: T.self)
    }

    private static func loadOptional<T>(_ symbol: String, from handle: UnsafeMutableRawPointer) -> T? {
        guard let pointer = dlsym(handle, symbol) else {
            return nil
        }
        return unsafeBitCast(pointer, to: T.self)
    }
}

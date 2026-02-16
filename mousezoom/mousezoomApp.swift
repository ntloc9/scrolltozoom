import SwiftUI
import CoreGraphics
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Constants
    private enum VirtualKey {
        static let plus: CGKeyCode = 0x18  // '+' key
        static let minus: CGKeyCode = 0x1B // '-' key
    }

    private enum UserDefaultsKey {
        static let commandModifier = "commandModifier"
        static let shiftModifier = "shiftModifier"
        static let controlModifier = "controlModifier"
        static let optionModifier = "optionModifier"
        static let sideButtonEnabled = "sideButtonEnabled"
        static let sideButtonApps = "sideButtonApps"
    }

    // MARK: - Properties
    var eventTap: CFMachPort?
    var sideButtonEventTap: CFMachPort?
    var settingsWindow: NSWindow?

    // MARK: - Application Lifecycle
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        guard checkAccessibilityPermissions() else {
            return
        }

        registerLoginItemIfFirstLaunch()
        setupEventTap()
        setupSideButtonEventTapIfNeeded()

        // If menu bar icon is hidden, open settings on launch so user can access them
        if UserDefaults.standard.bool(forKey: "hideMenuBarIcon") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.openSettings()
            }
        }

        // Observe changes to side button setting
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sideButtonSettingChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    @objc private func sideButtonSettingChanged() {
        setupSideButtonEventTapIfNeeded()
    }

    // MARK: - Login Item
    private func registerLoginItemIfFirstLaunch() {
        let hasLaunchedKey = "hasLaunchedBefore"
        if !UserDefaults.standard.bool(forKey: hasLaunchedKey) {
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
            try? SMAppService.mainApp.register()
        }
    }

    // MARK: - Accessibility Permissions
    private func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if !accessEnabled {
            showAccessibilityAlert()
            NSApp.terminate(self)
            return false
        }

        return true
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Enable Accessibility Access"
        alert.informativeText = "mou mou needs accessibility permissions to function. Please enable it in System Settings > Privacy & Security > Accessibility."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Quit")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Event Tap Setup
    func setupEventTap() {
        let eventMask = (1 << CGEventType.scrollWheel.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                return AppDelegate.handleScrollEvent(type: type, event: event)
            },
            userInfo: nil
        )

        if let eventTap = eventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }

    func setupSideButtonEventTapIfNeeded() {
        let isEnabled = UserDefaults.standard.bool(forKey: UserDefaultsKey.sideButtonEnabled)

        if isEnabled {
            if sideButtonEventTap == nil {
                createSideButtonEventTap()
            }
        } else {
            if let tap = sideButtonEventTap {
                CGEvent.tapEnable(tap: tap, enable: false)
                sideButtonEventTap = nil
            }
        }
    }

    private func createSideButtonEventTap() {
        let eventMask = (1 << CGEventType.otherMouseDown.rawValue) | (1 << CGEventType.otherMouseUp.rawValue)

        sideButtonEventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                return AppDelegate.handleSideButtonEvent(type: type, event: event)
            },
            userInfo: nil
        )

        if let tap = sideButtonEventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    // MARK: - Event Handling
    private static func handleSideButtonEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .otherMouseDown || type == .otherMouseUp else {
            return Unmanaged.passRetained(event)
        }

        // Only intercept in configured apps
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontApp.bundleIdentifier else {
            return Unmanaged.passRetained(event)
        }
        let apps = UserDefaults.standard.stringArray(forKey: UserDefaultsKey.sideButtonApps) ?? ["com.apple.finder"]
        guard apps.contains(bundleId) else {
            return Unmanaged.passRetained(event)
        }

        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
        let isDown = (type == .otherMouseDown)

        // Button 3 = Back, Button 4 = Forward
        if buttonNumber == 3 {
            if isDown {
                simulateNavigation(back: true)
            }
            return nil // Suppress the button event
        } else if buttonNumber == 4 {
            if isDown {
                simulateNavigation(back: false)
            }
            return nil // Suppress the button event
        }

        return Unmanaged.passRetained(event)
    }

    private static func handleScrollEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .scrollWheel else {
            return Unmanaged.passRetained(event)
        }

        let requiredFlags = getRequiredModifierFlags()

        guard event.flags.contains(requiredFlags) else {
            return Unmanaged.passRetained(event)
        }

        let scrollDelta = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)

        if scrollDelta > 0 {
            // Scroll up - zoom out
            simulateKeyPress(virtualKey: VirtualKey.minus)
            return nil // Suppress the original scroll event
        } else if scrollDelta < 0 {
            // Scroll down - zoom in
            simulateKeyPress(virtualKey: VirtualKey.plus)
            return nil // Suppress the original scroll event
        }

        return Unmanaged.passRetained(event)
    }

    private static func getRequiredModifierFlags() -> CGEventFlags {
        var flags: CGEventFlags = []

        if UserDefaults.standard.bool(forKey: UserDefaultsKey.commandModifier) {
            flags.insert(.maskCommand)
        }
        if UserDefaults.standard.bool(forKey: UserDefaultsKey.shiftModifier) {
            flags.insert(.maskShift)
        }
        if UserDefaults.standard.bool(forKey: UserDefaultsKey.controlModifier) {
            flags.insert(.maskControl)
        }
        if UserDefaults.standard.bool(forKey: UserDefaultsKey.optionModifier) {
            flags.insert(.maskAlternate)
        }

        return flags
    }

    private static func simulateKeyPress(virtualKey: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true)
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }

    private static func simulateNavigation(back: Bool) {
        let source = CGEventSource(stateID: .hidSystemState)
        // Cmd+[ for back, Cmd+] for forward
        let virtualKey: CGKeyCode = back ? 0x21 : 0x1E

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true)
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }

    // MARK: - Settings Window
    @objc func openSettings() {
        if settingsWindow == nil {
            settingsWindow = createSettingsWindow()
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
private func createSettingsWindow() -> NSWindow {
        let settingsView = SettingsView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 250),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "mou mou Settings"
        window.center()
        window.setFrameAutosaveName("Settings")
        window.contentView = NSHostingView(rootView: settingsView)
        window.isReleasedWhenClosed = false
        return window
    }
}

@main
struct mousezoomApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("hideMenuBarIcon") private var hideMenuBarIcon = false

    var body: some Scene {
        MenuBarExtra("mou mou", systemImage: "plus.magnifyingglass", isInserted: Binding(
            get: { !hideMenuBarIcon },
            set: { hideMenuBarIcon = !$0 }
        )) {
            Button("Settings") {
                appDelegate.openSettings()
            }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

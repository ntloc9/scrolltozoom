import SwiftUI
import CoreGraphics

class AppDelegate: NSObject, NSApplicationDelegate {
    var eventTap: CFMachPort?
    var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Check for accessibility permissions
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if !accessEnabled {
            print("Accessibility permissions are not enabled. Please enable them in System Settings.")
            // Optionally, you can open the settings pane for the user
            let alert = NSAlert()
            alert.messageText = "Enable Accessibility Access"
            alert.informativeText = "MouseZoom needs accessibility permissions to function. Please enable it in System Settings > Privacy & Security > Accessibility."
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Quit")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            NSApp.terminate(self)
            return
        }

        setupEventTap()
    }

    func setupEventTap() {
        let eventMask = (1 << CGEventType.scrollWheel.rawValue)
        
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                if type == .scrollWheel {
                    let commandModifier = UserDefaults.standard.bool(forKey: "commandModifier")
                    let shiftModifier = UserDefaults.standard.bool(forKey: "shiftModifier")
                    let controlModifier = UserDefaults.standard.bool(forKey: "controlModifier")
                    let optionModifier = UserDefaults.standard.bool(forKey: "optionModifier")
                    let reverseScroll = UserDefaults.standard.bool(forKey: "reverseScroll")
                    var plusKeyStr: CGKeyCode = 0x18 // 0x18 is '+'
                    var downKeyStr: CGKeyCode = 0x1B // 0x1B is '-'

                    var requiredFlags: CGEventFlags = []
                    if commandModifier {
                        requiredFlags.insert(.maskCommand)
                    }
                    if shiftModifier {
                        requiredFlags.insert(.maskShift)
                    }
                    if controlModifier {
                        requiredFlags.insert(.maskControl)
                    }
                    if optionModifier {
                        requiredFlags.insert(.maskAlternate)
                    }
                    
                    if reverseScroll {
                        plusKeyStr = 0x1B // 0x1B is '-'
                        downKeyStr = 0x18 // 0x18 is '+'
                    }
                    
                    if event.flags.contains(requiredFlags) {
                        let scroll = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
                        if scroll > 0 {
                            // Scroll Up, simulate zoom in (using plusKeyStr)
                            let source = CGEventSource(stateID: .hidSystemState)
                            let keyEventDown = CGEvent(keyboardEventSource: source, virtualKey: plusKeyStr, keyDown: true)
                            keyEventDown?.flags = requiredFlags
                            let keyEventUp = CGEvent(keyboardEventSource: source, virtualKey: plusKeyStr, keyDown: false)
                            keyEventUp?.flags = requiredFlags

                            keyEventDown?.post(tap: .cgAnnotatedSessionEventTap)
                            keyEventUp?.post(tap: .cgAnnotatedSessionEventTap)

                            // Suppress the original scroll event
                            return nil
                        } else if scroll < 0 {
                            // Scroll Down, simulate zoom out (using downKeyStr)
                            let source = CGEventSource(stateID: .hidSystemState)
                            let keyEventDown = CGEvent(keyboardEventSource: source, virtualKey: downKeyStr, keyDown: true)
                            keyEventDown?.flags = requiredFlags
                            let keyEventUp = CGEvent(keyboardEventSource: source, virtualKey: downKeyStr, keyDown: false)
                            keyEventUp?.flags = requiredFlags

                            keyEventDown?.post(tap: .cgAnnotatedSessionEventTap)
                            keyEventUp?.post(tap: .cgAnnotatedSessionEventTap)

                            // Suppress the original scroll event
                            return nil
                        }
                    }
                }
                // Pass on the event
                return Unmanaged.passRetained(event)
            },
            userInfo: nil
        )

        if let eventTap = eventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }
    
    @objc func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 250),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.center()
            settingsWindow?.setFrameAutosaveName("Settings")
            settingsWindow?.contentView = NSHostingView(rootView: settingsView)
            settingsWindow?.isReleasedWhenClosed = false
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct mousezoomApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("MouseZoom", systemImage: "plus.magnifyingglass") {
            Button("Settings") {
                appDelegate.openSettings()
            }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

import SwiftUI
import ServiceManagement

enum SettingsTab: String, CaseIterable {
    case scrollToZoom = "Scroll to zoom"
    case sideButton = "Side Button"
    case advance = "Advance"
}

struct SettingsView: View {
    // MARK: - Properties
    @AppStorage("commandModifier") private var commandModifier = true
    @AppStorage("shiftModifier") private var shiftModifier = false
    @AppStorage("controlModifier") private var controlModifier = false
    @AppStorage("optionModifier") private var optionModifier = false
    @AppStorage("sideButtonEnabled") private var sideButtonEnabled = false
    @State private var sideButtonApps: [String] = UserDefaults.standard.stringArray(forKey: "sideButtonApps") ?? ["com.apple.finder"]
    @State private var newAppBundleId: String = ""
    @State private var launchAtStartup: Bool = SMAppService.mainApp.status == .enabled
    @AppStorage("hideMenuBarIcon") private var hideMenuBarIcon = false
    @State private var selectedTab: SettingsTab = .scrollToZoom

    // MARK: - Body
    var body: some View {
        VStack(spacing: 12) {
            Picker("", selection: $selectedTab) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top)

            Group {
                switch selectedTab {
                case .scrollToZoom:
                    scrollToZoomTab
                case .sideButton:
                    sideButtonTab
                case .advance:
                    advanceTab
                }
            }

            Spacer()

            Button("Close") {
                NSApplication.shared.keyWindow?.close()
            }
            .keyboardShortcut(.defaultAction)
            .padding(.bottom)
        }
        .frame(width: 400, height: 380)
    }

    // MARK: - Tabs
    private var scrollToZoomTab: some View {
        Form {
            Toggle("⌘ Command", isOn: $commandModifier)
            Toggle("⇧ Shift", isOn: $shiftModifier)
            Toggle("⌃ Control", isOn: $controlModifier)
            Toggle("⌥ Option", isOn: $optionModifier)
        }
        .padding(.horizontal)
    }

    private var sideButtonTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Form {
                Toggle("Enable", isOn: $sideButtonEnabled)
            }

            Text("Active Apps")
                .font(.caption)
                .foregroundColor(.secondary)

            List {
                ForEach(sideButtonApps, id: \.self) { app in
                    HStack {
                        Text(app)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                        Spacer()
                        Button {
                            sideButtonApps.removeAll { $0 == app }
                            saveSideButtonApps()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 80)

            HStack {
                TextField("Bundle ID (e.g. com.apple.finder)", text: $newAppBundleId)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Button("Add") {
                    let trimmed = newAppBundleId.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty && !sideButtonApps.contains(trimmed) {
                        sideButtonApps.append(trimmed)
                        saveSideButtonApps()
                        newAppBundleId = ""
                    }
                }
                .disabled(newAppBundleId.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.horizontal)
    }

    @State private var showHideIconAlert = false

    private var advanceTab: some View {
        Form {
            Toggle("Run with startup", isOn: $launchAtStartup)
                .onChange(of: launchAtStartup) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        print("Failed to update login item: \(error)")
                        launchAtStartup = !newValue
                    }
                }
            Toggle("Hide icon in menu bar", isOn: $hideMenuBarIcon)
                .onChange(of: hideMenuBarIcon) { _, newValue in
                    if newValue {
                        showHideIconAlert = true
                    }
                }
        }
        .padding(.horizontal)
        .alert("Hide Menu Bar Icon", isPresented: $showHideIconAlert) {
            Button("Hide") { }
            Button("Cancel", role: .cancel) {
                hideMenuBarIcon = false
            }
        } message: {
            Text("To show the icon again, relaunch the app from Applications.")
        }
    }

    private func saveSideButtonApps() {
        UserDefaults.standard.set(sideButtonApps, forKey: "sideButtonApps")
    }
}

#Preview {
    SettingsView()
}

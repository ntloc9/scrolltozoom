
import SwiftUI

struct SettingsView: View {
    @AppStorage("commandModifier") private var commandModifier = true
    @AppStorage("shiftModifier") private var shiftModifier = false
    @AppStorage("controlModifier") private var controlModifier = false
    @AppStorage("optionModifier") private var optionModifier = false

    var body: some View {
        VStack {
            Text("Shortcut Settings")
                .font(.title)
                .padding()

            Form {
                Toggle("Command", isOn: $commandModifier)
                Toggle("Shift", isOn: $shiftModifier)
                Toggle("Control", isOn: $controlModifier)
                Toggle("Option", isOn: $optionModifier)
            }
            .padding()

            Spacer()

            Button("Close") {
                NSApplication.shared.keyWindow?.close()
            }
            .padding()
        }
        .frame(width: 300, height: 250)
    }
}

#Preview {
    SettingsView()
}

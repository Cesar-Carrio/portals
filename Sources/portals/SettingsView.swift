import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Shortcuts") {
                LabeledContent("Save snapshot", value: "⌃⌥⌘ S")
                LabeledContent("Restore snapshot", value: "⌃⌥⌘ R")
                Text("Hotkeys are fixed in this build. They can be made configurable later.")
                    .font(.caption)
            }
            Section("Notes") {
                Text("Layouts are stored per display. Missing displays are skipped and windows scale to resolution changes. Extra windows are staged in the center of the main display.")
            }
        }
        .padding()
        .frame(width: 420)
    }
}

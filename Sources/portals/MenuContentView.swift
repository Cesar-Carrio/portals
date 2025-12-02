import SwiftUI

struct MenuContentView: View {
    @EnvironmentObject var model: AppModel
    @State private var newProfileName: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active profile")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker(
                "Profile",
                selection: Binding(
                    get: { model.activeProfileID ?? model.profiles.first?.id ?? UUID() },
                    set: { model.setActiveProfile(id: $0) }
                )
            ) {
                ForEach(model.profiles) { profile in
                    Text(profile.name).tag(profile.id)
                }
            }
            .labelsHidden()

            HStack {
                TextField("New profile name", text: $newProfileName)
                    .onSubmit(addProfile)
                Button("Add", action: addProfile)
                    .buttonStyle(.bordered)
                    .tint(.blue)
            }

            Divider()

            HStack {
                Button("Save Snapshot") {
                    model.saveSnapshot()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                Button("Restore") {
                    model.restoreSnapshot()
                }
                .buttonStyle(.bordered)
                .tint(.blue)
            }

            Button("Reset Profile") {
                model.resetCurrentProfile()
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .disabled(model.currentProfile?.windows.isEmpty ?? true)

            if let profile = model.currentProfile {
                if profile.windows.isEmpty {
                    Label("This profile has no saved positions.", systemImage: "slash.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Saved windows: \(profile.windows.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if model.awaitingAccessibility {
                Label("Grant Accessibility access to control windows.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }

            Text(model.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Button("Quit Portals") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding(12)
        .frame(minWidth: 260)
    }

    private func addProfile() {
        model.addProfile(named: newProfileName)
        newProfileName = ""
    }
}

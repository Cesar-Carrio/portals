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
            }

            Divider()

            HStack {
                Button("Save Snapshot") {
                    model.saveSnapshot()
                }
                Button("Restore") {
                    model.restoreSnapshot()
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
        }
        .padding(12)
        .frame(minWidth: 260)
    }

    private func addProfile() {
        model.addProfile(named: newProfileName)
        newProfileName = ""
    }
}

import SwiftUI

@main
struct PortalsApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Portals", systemImage: "square.grid.2x2") {
            MenuContentView()
                .environmentObject(model)
        }
        .menuBarExtraStyle(.window)
        Settings {
            SettingsView()
        }
    }
}

import Foundation

final class SnapshotStore {
    private let fileURL: URL

    init() {
        let fm = FileManager.default
        let supportDir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = supportDir.appendingPathComponent("Portals", isDirectory: true)
        try? fm.createDirectory(at: appDir, withIntermediateDirectories: true)
        fileURL = appDir.appendingPathComponent("profiles.json")
    }

    func loadProfiles() -> [SnapshotProfile] {
        guard let data = try? Data(contentsOf: fileURL) else {
            return [SnapshotProfile(name: "Default")]
        }
        do {
            return try JSONDecoder().decode([SnapshotProfile].self, from: data)
        } catch {
            return [SnapshotProfile(name: "Default")]
        }
    }

    func saveProfiles(_ profiles: [SnapshotProfile]) {
        do {
            let data = try JSONEncoder().encode(profiles)
            try data.write(to: fileURL)
        } catch {
            print("Failed to save profiles: \(error)")
        }
    }
}

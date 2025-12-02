import Foundation
import CoreGraphics

struct WindowSnapshot: Identifiable, Codable {
    let id: UUID
    let bundleID: String
    let windowTitle: String
    let displayID: UInt32
    let normalizedFrame: CGRect

    init(bundleID: String, windowTitle: String, displayID: UInt32, normalizedFrame: CGRect) {
        self.id = UUID()
        self.bundleID = bundleID
        self.windowTitle = windowTitle
        self.displayID = displayID
        self.normalizedFrame = normalizedFrame
    }
}

struct SnapshotProfile: Identifiable, Codable {
    let id: UUID
    var name: String
    var windows: [WindowSnapshot]

    init(id: UUID = UUID(), name: String, windows: [WindowSnapshot] = []) {
        self.id = id
        self.name = name
        self.windows = windows
    }
}

struct RestoreReport {
    var restored: Int
    var skippedDisplays: [UInt32]
    var missingApps: [String]
    var missingWindows: [String]
    var minimizedExtraWindows: Int
}

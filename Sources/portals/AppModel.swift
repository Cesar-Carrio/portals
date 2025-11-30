import AppKit
import Carbon
import Combine
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var profiles: [SnapshotProfile] = []
    @Published var activeProfileID: UUID?
    @Published var statusMessage: String = "Ready"
    @Published var awaitingAccessibility: Bool = false

    private let store = SnapshotStore()
    private let windowManager = WindowManager()
    private let hotKeys = HotKeyManager()
    private let authorizer = AccessibilityAuthorizer()

    private let snapshotHotKeyID: UInt32 = 1
    private let restoreHotKeyID: UInt32 = 2

    private let snapshotCombo = KeyCombo(keyCode: 1, modifiers: UInt32(controlKey | optionKey | cmdKey))
    private let restoreCombo = KeyCombo(keyCode: 15, modifiers: UInt32(controlKey | optionKey | cmdKey))

    init() {
        profiles = store.loadProfiles()
        if profiles.isEmpty {
            profiles = [SnapshotProfile(name: "Default")]
        }
        activeProfileID = profiles.first?.id
        setupHotKeys()
        authorizer.requestIfNeeded()
        awaitingAccessibility = !AXIsProcessTrusted()
    }

    func addProfile(named name: String) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if profiles.contains(where: { $0.name == name }) { return }
        let newProfile = SnapshotProfile(name: name)
        profiles.append(newProfile)
        activeProfileID = newProfile.id
        store.saveProfiles(profiles)
    }

    func deleteProfile(_ profile: SnapshotProfile) {
        profiles.removeAll { $0.id == profile.id }
        if profiles.isEmpty {
            profiles.append(SnapshotProfile(name: "Default"))
        }
        ensureActiveProfile()
        store.saveProfiles(profiles)
    }

    func setActiveProfile(id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        activeProfileID = id
    }

    func saveSnapshot() {
        guard AXIsProcessTrusted() else {
            awaitingAccessibility = true
            statusMessage = "Enable Accessibility permissions to save layouts."
            authorizer.requestIfNeeded()
            return
        }

        guard var profile = currentProfile else { return }
        let snapshot = windowManager.captureSnapshot()
        profile.windows = snapshot
        updateProfile(profile)
        statusMessage = "Saved \(snapshot.count) windows to \(profile.name)."
        ScreenFlash.flash()
    }

    func restoreSnapshot() {
        guard AXIsProcessTrusted() else {
            awaitingAccessibility = true
            statusMessage = "Enable Accessibility permissions to restore layouts."
            authorizer.requestIfNeeded()
            return
        }
        guard let profile = currentProfile else { return }

        statusMessage = "Restoring \(profile.windows.count) windows..."
        Task {
            let report = await windowManager.restore(profile: profile)
            await MainActor.run {
                var parts: [String] = []
                parts.append("Restored \(report.restored)")
                if !report.skippedDisplays.isEmpty {
                    parts.append("Skipped displays: \(report.skippedDisplays)")
                }
                if !report.missingApps.isEmpty {
                    parts.append("Missing apps: \(report.missingApps.joined(separator: ", "))")
                }
                if !report.missingWindows.isEmpty {
                    parts.append("Missing windows: \(report.missingWindows.count)")
                }
                if report.stagedExtraWindows > 0 {
                    parts.append("Staged \(report.stagedExtraWindows) extras")
                }
                statusMessage = parts.joined(separator: " • ")
            }
        }
    }

    private var currentProfile: SnapshotProfile? {
        guard let id = activeProfileID else { return profiles.first }
        return profiles.first(where: { $0.id == id }) ?? profiles.first
    }

    private func updateProfile(_ profile: SnapshotProfile) {
        if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[idx] = profile
        } else {
            profiles.append(profile)
        }
        store.saveProfiles(profiles)
    }

    private func ensureActiveProfile() {
        if let activeID = activeProfileID, profiles.contains(where: { $0.id == activeID }) {
            return
        }
        activeProfileID = profiles.first?.id
    }

    private func setupHotKeys() {
        hotKeys.register(id: snapshotHotKeyID, combo: snapshotCombo) { [weak self] in
            Task { @MainActor in
                self?.saveSnapshot()
            }
        }
        hotKeys.register(id: restoreHotKeyID, combo: restoreCombo) { [weak self] in
            Task { @MainActor in
                self?.restoreSnapshot()
            }
        }
    }
}

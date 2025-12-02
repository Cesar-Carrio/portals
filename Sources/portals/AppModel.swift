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
    private var cancellables = Set<AnyCancellable>()

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
        bindAuthorizer()
        setupHotKeys()
        authorizer.requestIfNeeded()
        awaitingAccessibility = !authorizer.isAuthorized
    }

    func addProfile(named name: String) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if profiles.contains(where: { $0.name == name }) { return }
        let newProfile = SnapshotProfile(name: name)
        profiles.append(newProfile)
        activeProfileID = newProfile.id
        statusMessage = "\(newProfile.name) has no saved positions."
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
        if let profile = currentProfile, profile.windows.isEmpty {
            statusMessage = "\(profile.name) has no saved positions."
        } else {
            statusMessage = "Ready"
        }
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
        guard !profile.windows.isEmpty else {
            statusMessage = "\(profile.name) has no saved positions."
            return
        }

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
                if report.minimizedExtraWindows > 0 {
                    parts.append("Minimized \(report.minimizedExtraWindows) extras")
                }
                statusMessage = parts.joined(separator: " • ")
            }
        }
    }

    func resetCurrentProfile() {
        guard var profile = currentProfile else { return }
        profile.windows = []
        updateProfile(profile)
        statusMessage = "\(profile.name) has no saved positions."
    }

    var currentProfile: SnapshotProfile? {
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

    private func bindAuthorizer() {
        authorizer.$isAuthorized
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthorized in
                guard let self else { return }
                let wasAwaiting = self.awaitingAccessibility
                self.awaitingAccessibility = !isAuthorized
                if isAuthorized && wasAwaiting {
                    self.statusMessage = "Accessibility permissions granted."
                }
            }
            .store(in: &cancellables)
    }
}

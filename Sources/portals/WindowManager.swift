import AppKit
import ApplicationServices
import Foundation

@MainActor
final class WindowManager {
    private let workspace = NSWorkspace.shared

    func captureSnapshot() -> [WindowSnapshot] {
        guard AXIsProcessTrusted() else { return [] }
        let apps = workspace.runningApplications.filter { $0.activationPolicy == .regular }
        var snapshots: [WindowSnapshot] = []

        for app in apps {
            let windows = windowsForApp(app)
            for window in windows {
                guard let frame = frame(of: window),
                      frame.width > 5, frame.height > 5,
                      let title = title(of: window), !title.isEmpty,
                      let screenInfo = screenInfo(for: frame) else { continue }

                if isFullscreen(window) || isMinimized(window) {
                    continue
                }

                let normalized = normalize(frame: frame, in: screenInfo.screen)
                let snapshot = WindowSnapshot(
                    bundleID: app.bundleIdentifier ?? "unknown",
                    windowTitle: title,
                    displayID: screenInfo.displayID,
                    normalizedFrame: normalized
                )
                snapshots.append(snapshot)
            }
        }

        return snapshots
    }

    func restore(profile: SnapshotProfile) async -> RestoreReport {
        var restored = 0
        var skippedDisplays: [UInt32] = []
        var missingApps: [String] = []
        var missingWindows: [String] = []
        var matchedWindowHashes = Set<Int>()

        for snapshot in profile.windows {
            guard let screen = screen(forDisplayID: snapshot.displayID) else {
                skippedDisplays.append(snapshot.displayID)
                continue
            }

            let appWasRunning = workspace.runningApplications.contains { $0.bundleIdentifier == snapshot.bundleID }

            guard let app = await ensureRunningApp(bundleID: snapshot.bundleID) else {
                missingApps.append(snapshot.bundleID)
                continue
            }

            let windows = await windowsForApp(
                app,
                waitForLaunch: !appWasRunning,
                expectedTitle: snapshot.windowTitle
            ).filter { !matchedWindowHashes.contains(hash(of: $0)) }
            guard let match = bestWindowMatch(for: snapshot, windows: windows) else {
                missingWindows.append("\(snapshot.bundleID) - \(snapshot.windowTitle)")
                continue
            }

            let frame = denormalize(frame: snapshot.normalizedFrame, in: screen)
            if setFrame(frame, for: match) {
                restored += 1
                matchedWindowHashes.insert(hash(of: match))
            } else {
                missingWindows.append("\(snapshot.bundleID) - \(snapshot.windowTitle)")
            }
        }

        let staged = stageExtraWindows(excluding: matchedWindowHashes)

        return RestoreReport(
            restored: restored,
            skippedDisplays: Array(Set(skippedDisplays)),
            missingApps: Array(Set(missingApps)),
            missingWindows: missingWindows,
            stagedExtraWindows: staged
        )
    }

    private func stageExtraWindows(excluding matched: Set<Int>) -> Int {
        guard let mainScreen = NSScreen.main else { return 0 }
        let center = CGPoint(x: mainScreen.frame.midX - 400, y: mainScreen.frame.midY - 300)
        let size = CGSize(width: 800, height: 600)
        var staged = 0

        let apps = workspace.runningApplications.filter { $0.activationPolicy == .regular }
        for app in apps {
            for window in windowsForApp(app) {
                if matched.contains(hash(of: window)) { continue }
                let target = CGRect(origin: center, size: size)
                if setFrame(target, for: window) {
                    staged += 1
                }
            }
        }
        return staged
    }

    private func bestWindowMatch(for snapshot: WindowSnapshot, windows: [AXUIElement]) -> AXUIElement? {
        var best: (AXUIElement, Int)?
        for window in windows {
            guard let title = title(of: window) else { continue }
            let score = matchScore(expected: snapshot.windowTitle, actual: title)
            if let current = best {
                if score > current.1 {
                    best = (window, score)
                }
            } else {
                best = (window, score)
            }
        }
        return best?.0
    }

    private func matchScore(expected: String, actual: String) -> Int {
        if expected == actual { return 100 }
        if actual.localizedCaseInsensitiveContains(expected) { return 80 }
        if expected.localizedCaseInsensitiveContains(actual) { return 60 }
        return 10
    }

    private func ensureRunningApp(bundleID: String) async -> NSRunningApplication? {
        if let app = workspace.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
            return app
        }

        guard let url = workspace.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        do {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = false
            config.hides = false
            let app = try await workspace.openApplication(at: url, configuration: config)
            try await Task.sleep(nanoseconds: 400_000_000)
            return app
        } catch {
            return nil
        }
    }

    private func normalize(frame: CGRect, in screen: NSScreen) -> CGRect {
        let rect = screen.frame
        return CGRect(
            x: (frame.minX - rect.minX) / rect.width,
            y: (frame.minY - rect.minY) / rect.height,
            width: frame.width / rect.width,
            height: frame.height / rect.height
        )
    }

    private func denormalize(frame: CGRect, in screen: NSScreen) -> CGRect {
        let rect = screen.frame
        return CGRect(
            x: rect.minX + frame.minX * rect.width,
            y: rect.minY + frame.minY * rect.height,
            width: frame.width * rect.width,
            height: frame.height * rect.height
        )
    }

    private func windowsForApp(_ app: NSRunningApplication) -> [AXUIElement] {
        guard let pid = app.processIdentifier as pid_t? else { return [] }
        let appElement = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
        guard result == .success, let array = value as? [AXUIElement] else { return [] }
        return array
    }

    private func windowsForApp(
        _ app: NSRunningApplication,
        waitForLaunch: Bool,
        expectedTitle: String
    ) async -> [AXUIElement] {
        var windows = windowsForApp(app)
        guard waitForLaunch else { return windows }

        let deadline = Date().addingTimeInterval(2.0)
        while !Task.isCancelled {
            if hasCandidateWindow(in: windows, expectedTitle: expectedTitle) || Date() > deadline {
                break
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
            windows = windowsForApp(app)
        }
        return windows
    }

    private func frame(of window: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        let posResult = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue)
        let sizeResult = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue)
        guard posResult == .success,
              sizeResult == .success,
              let posRaw = positionValue,
              let sizeRaw = sizeValue,
              CFGetTypeID(posRaw) == AXValueGetTypeID(),
              CFGetTypeID(sizeRaw) == AXValueGetTypeID() else { return nil }

        var position = CGPoint.zero
        var sizeStruct = CGSize.zero
        AXValueGetValue((posRaw as! AXValue), .cgPoint, &position)
        AXValueGetValue((sizeRaw as! AXValue), .cgSize, &sizeStruct)
        return CGRect(origin: position, size: sizeStruct)
    }

    private func title(of window: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &value)
        return result == .success ? (value as? String) : nil
    }

    private func isFullscreen(_ window: AXUIElement) -> Bool {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &value)
        if result == .success, let boolValue = value as? Bool {
            return boolValue
        }
        return false
    }

    private func isMinimized(_ window: AXUIElement) -> Bool {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &value)
        if result == .success, let boolValue = value as? Bool {
            return boolValue
        }
        return false
    }

    private func screenInfo(for frame: CGRect) -> (displayID: UInt32, screen: NSScreen)? {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(frame.center) }) else {
            return nil
        }
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return (number.uint32Value, screen)
    }

    private func screen(forDisplayID id: UInt32) -> NSScreen? {
        return NSScreen.screens.first { screen in
            if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                return number.uint32Value == id
            }
            return false
        }
    }

    private func setFrame(_ frame: CGRect, for window: AXUIElement) -> Bool {
        var pos = frame.origin
        var size = frame.size
        guard let posValue = AXValueCreate(.cgPoint, &pos),
              let sizeValue = AXValueCreate(.cgSize, &size) else {
            return false
        }
        let posResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        let sizeResult = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        return posResult == .success && sizeResult == .success
    }

    private func hash(of element: AXUIElement) -> Int {
        return Int(CFHash(element))
    }

    private func hasCandidateWindow(in windows: [AXUIElement], expectedTitle: String) -> Bool {
        for window in windows {
            guard let title = title(of: window) else { continue }
            if matchScore(expected: expectedTitle, actual: title) > 10 {
                return true
            }
        }
        return false
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}

@preconcurrency import ApplicationServices
import Foundation

@MainActor
final class AccessibilityAuthorizer: ObservableObject {
    @Published private(set) var isAuthorized: Bool = AXIsProcessTrusted()

    func requestIfNeeded() {
        guard !isAuthorized else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.isAuthorized = AXIsProcessTrusted()
        }
    }
}

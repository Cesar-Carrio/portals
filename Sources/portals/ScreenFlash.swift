import AppKit
import Foundation

enum ScreenFlash {
    @MainActor
    static func flash(duration: TimeInterval = 0.25) {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        var windows: [NSWindow] = []
        for screen in screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = NSColor.white.withAlphaComponent(0.35)
            window.ignoresMouseEvents = true
            window.alphaValue = 0
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            for window in windows {
                window.animator().alphaValue = 1.0
            }
        } completionHandler: {
            Task { @MainActor in
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = duration
                    for window in windows {
                        window.animator().alphaValue = 0.0
                    }
                } completionHandler: {
                    Task { @MainActor in
                        for window in windows {
                            window.orderOut(nil)
                        }
                    }
                }
            }
        }
    }
}

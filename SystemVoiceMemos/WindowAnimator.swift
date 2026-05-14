import AppKit
import SwiftUI

@MainActor
final class WindowAnimator: ObservableObject {
    private var savedFrame: NSRect?
    private var weakWindow: NSWindow?

    private var mainWindow: NSWindow? {
        // Use stored weak reference if available and valid, otherwise search
        if let window = weakWindow {
            // Check if window is still valid by seeing if it's in the app's windows
            if NSApp.windows.contains(where: { $0 === window }) {
                return window
            }
        }

        // Filter for the specific main application window more strictly
        let found = NSApp.windows.first { window in
            !(window is NSPanel) && window.isVisible && window.identifier?.rawValue == "main_window"
        } ?? NSApp.mainWindow

        // Cache the found window for future use
        weakWindow = found
        return found
    }

    @Published var isMinimized = false

    /// Store the window reference before shrinking
    func captureWindow() {
        weakWindow = mainWindow
    }

    func shrinkToBar() {
        captureWindow() // Ensure we have a reference before shrinking
        guard let window = mainWindow, !isMinimized else { return }

        savedFrame = window.frame
        isMinimized = true // Set immediately, not after animation

        // Just minimize the window instead of hiding it
        window.miniaturize(nil)
    }

    /// Restores the main app window from a minimized or shrunk state to its saved full frame and brings it to the front.
    /// 
    /// If the application is hidden, it is unhidden. If the window is miniaturized it will be deminiaturized. If a previously saved frame exists, the window frame is restored with animation. The window is then made key and ordered front, the app is activated, `isMinimized` is set to `false`, and the saved frame is cleared.
    func expandToFull() {
        // Ensure we have a valid window reference
        captureWindow()
        guard let window = mainWindow else {
            // No window found, can't expand
            return
        }

        NSApp.unhide(nil)

        // Deminiaturize if minimized
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        // Restore saved frame if available
        if let targetFrame = savedFrame {
            window.setFrame(targetFrame, display: true, animate: true)
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        isMinimized = false
        savedFrame = nil
    }

    /// Restores the app window to its saved frame (or a centered default) immediately and without animation.
    /// 
    /// If a saved frame exists, the window is positioned to that rect; otherwise the window is centered on the main (or first) screen with a 960×700 size. The application is unhidden, the window is ordered front, made key, its alpha is set to fully opaque, `isMinimized` is set to `false`, and the saved frame is cleared.
    func restoreWithoutAnimation() {
        // Ensure we have a valid window reference
        captureWindow()
        guard let window = mainWindow else { return }

        NSApp.unhide(nil)

        let defaultFrame: NSRect = {
            let screen = NSScreen.main ?? NSScreen.screens.first!
            let size = NSSize(width: 960, height: 700)
            let origin = NSPoint(
                x: screen.visibleFrame.midX - size.width / 2,
                y: screen.visibleFrame.midY - size.height / 2
            )
            return NSRect(origin: origin, size: size)
        }()
        let targetFrame = savedFrame ?? defaultFrame

        window.setFrame(targetFrame, display: true)
        window.alphaValue = 1
        window.orderFront(nil)
        window.makeKey()
        NSApp.activate(ignoringOtherApps: true)
        isMinimized = false
        savedFrame = nil
    }
}

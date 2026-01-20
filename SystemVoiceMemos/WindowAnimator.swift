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

    // Store the window reference before shrinking
    func captureWindow() {
        weakWindow = mainWindow
    }
    
    func shrinkToBar() {
        captureWindow()  // Ensure we have a reference before shrinking
        guard let window = mainWindow, !isMinimized else { return }

        savedFrame = window.frame
        isMinimized = true  // Set immediately, not after animation

        // Just minimize the window instead of hiding it
        window.miniaturize(nil)
    }

    func expandToFull() {
        // Ensure we have a valid window reference
        captureWindow()
        guard let window = mainWindow else {
            // No window found, can't expand
            return
        }

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

    func restoreWithoutAnimation() {
        // Ensure we have a valid window reference
        captureWindow()
        guard let window = mainWindow else { return }

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
        self.savedFrame = nil
    }
}

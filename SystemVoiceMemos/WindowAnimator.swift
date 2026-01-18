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

        // Fallback to searching windows
        let found = NSApp.windows.first {
            $0.contentView?.subviews.first is NSHostingView<AnyView> ||
            $0.title.isEmpty && $0.styleMask.contains(.fullSizeContentView)
        } ?? NSApp.mainWindow
        ?? NSApp.windows.first { !($0 is NSPanel) }

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

        let barSize = NSSize(width: 360, height: 52)
        let screen = window.screen ?? NSScreen.main!
        let newOrigin = NSPoint(
            x: screen.visibleFrame.midX - barSize.width / 2,
            y: screen.visibleFrame.minY + 80
        )
        let newFrame = NSRect(origin: newOrigin, size: barSize)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newFrame, display: true)
            window.animator().alphaValue = 0
        } completionHandler: {
            window.orderOut(nil)
        }
    }

    func expandToFull() {
        // Ensure we have a valid window reference
        captureWindow()
        guard let window = mainWindow else {
            // No window found, can't expand
            return
        }

        // If we don't have a saved frame, use a default centered frame
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

        window.setFrame(NSRect(
            x: targetFrame.midX - 180,
            y: targetFrame.minY,
            width: 360,
            height: 52
        ), display: false)
        window.alphaValue = 0
        window.orderFront(nil)
        window.makeKey()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(targetFrame, display: true)
            window.animator().alphaValue = 1
        } completionHandler: { [weak self] in
            Task { @MainActor in
                self?.isMinimized = false
                self?.savedFrame = nil
                // Activate app so window gets keyboard focus
                NSApp.activate(ignoringOtherApps: true)
            }
        }
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

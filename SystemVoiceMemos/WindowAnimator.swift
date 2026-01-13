import AppKit
import SwiftUI

@MainActor
final class WindowAnimator: ObservableObject {
    private var savedFrame: NSRect?
    private var mainWindow: NSWindow? {
        NSApp.windows.first { $0.contentView?.subviews.first is NSHostingView<AnyView> || $0.title.isEmpty && $0.styleMask.contains(.fullSizeContentView) }
            ?? NSApp.mainWindow
            ?? NSApp.windows.first { !($0 is NSPanel) }
    }
    
    @Published var isMinimized = false
    
    func shrinkToBar() {
        guard let window = mainWindow, !isMinimized else { return }
        
        savedFrame = window.frame
        
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
        } completionHandler: { [weak self] in
            window.orderOut(nil)
            self?.isMinimized = true
        }
    }
    
    func expandToFull() {
        guard let window = mainWindow, let savedFrame = savedFrame else { return }
        
        window.setFrame(NSRect(
            x: savedFrame.midX - 180,
            y: savedFrame.minY,
            width: 360,
            height: 52
        ), display: false)
        window.alphaValue = 0
        window.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(savedFrame, display: true)
            window.animator().alphaValue = 1
        } completionHandler: { [weak self] in
            self?.isMinimized = false
            self?.savedFrame = nil
        }
    }
    
    func restoreWithoutAnimation() {
        guard let window = mainWindow, let savedFrame = savedFrame else { return }
        
        window.setFrame(savedFrame, display: true)
        window.alphaValue = 1
        window.orderFront(nil)
        isMinimized = false
        self.savedFrame = nil
    }
}

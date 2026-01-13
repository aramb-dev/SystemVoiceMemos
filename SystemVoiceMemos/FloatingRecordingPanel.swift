import SwiftUI
import AppKit

@MainActor
final class FloatingRecordingPanel: ObservableObject {
    private var panel: NSPanel?
    private var recorder: SystemAudioRecorder?
    
    @Published var isVisible = false
    @AppStorage("minimalRecordingAlwaysOnTop") var isAlwaysOnTop = true
    
    var onStop: (() -> Void)?
    var onRestart: (() -> Void)?
    
    func show(recorder: SystemAudioRecorder) {
        self.recorder = recorder
        
        if panel == nil {
            createPanel()
        }
        
        updateContent()
        panel?.orderFront(nil)
        isVisible = true
    }
    
    func hide() {
        panel?.orderOut(nil)
        isVisible = false
    }
    
    func close() {
        panel?.close()
        panel = nil
        isVisible = false
    }
    
    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 52),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Exclude from screen capture/sharing
        panel.sharingType = .none
        
        // Set initial level
        updateWindowLevel()
        
        // Center horizontally at bottom of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 160
            let y = screenFrame.minY + 80
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        self.panel = panel
    }
    
    private func updateContent() {
        guard let panel = panel, let recorder = recorder else { return }
        
        let isOnTopBinding = Binding<Bool>(
            get: { [weak self] in self?.isAlwaysOnTop ?? true },
            set: { [weak self] newValue in
                self?.isAlwaysOnTop = newValue
                self?.updateWindowLevel()
            }
        )
        
        let contentView = MinimalRecordingView(
            recorder: recorder,
            isAlwaysOnTop: isOnTopBinding,
            onStop: { [weak self] in self?.onStop?() },
            onRestart: { [weak self] in self?.onRestart?() }
        )
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = panel.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        
        panel.contentView = hostingView
    }
    
    private func updateWindowLevel() {
        panel?.level = isAlwaysOnTop ? .floating : .normal
    }
}

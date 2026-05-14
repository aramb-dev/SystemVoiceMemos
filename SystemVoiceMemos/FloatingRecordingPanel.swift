import AppKit
import SwiftUI

@MainActor
final class FloatingRecordingPanel: NSObject, ObservableObject, NSWindowDelegate {
    private let panelSize = NSSize(width: 344, height: 64)
    private let screenMargin: CGFloat = 10

    private var panel: NSPanel?
    private var recorder: SystemAudioRecorder?
    private var isClampingFrame = false

    @Published var isVisible = false
    @AppStorage("minimalRecordingAlwaysOnTop") var isAlwaysOnTop = true
    @AppStorage(AppConstants.UserDefaultsKeys.hideFromScreenSharing) private var excludeFromScreenCapture = true

    var onStop: (() -> Void)?
    var onRestart: (() -> Void)?
    var onExpand: (() -> Void)?

    func show(recorder: SystemAudioRecorder) {
        self.recorder = recorder

        if panel == nil {
            createPanel()
        }

        updateWindowBehavior()
        updateContent()
        clampToVisibleScreen()
        panel?.orderFrontRegardless()
        isVisible = true
    }

    func hide() {
        panel?.orderOut(nil)
        isVisible = false
    }

    func close() {
        panel?.delegate = nil
        panel?.close()
        panel = nil
        isVisible = false
    }

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.canHide = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = collectionBehavior
        panel.delegate = self

        // Exclude from screen capture/sharing if requested
        panel.sharingType = excludeFromScreenCapture ? .none : .readOnly

        // Set initial level
        updateWindowLevel()

        // Center horizontally at bottom of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - (panelSize.width / 2)
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
                self?.updateWindowBehavior()
            }
        )

        let contentView = MinimalRecordingView(
            recorder: recorder,
            isAlwaysOnTop: isOnTopBinding,
            onStop: { [weak self] in self?.onStop?() },
            onRestart: { [weak self] in self?.onRestart?() },
            onExpand: { [weak self] in self?.onExpand?() }
        )

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = panel.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        panel.contentView = hostingView
    }

    private func updateWindowLevel() {
        panel?.level = isAlwaysOnTop ? .statusBar : .normal
    }

    private var collectionBehavior: NSWindow.CollectionBehavior {
        if isAlwaysOnTop {
            return [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        }
        return [.canJoinAllSpaces, .fullScreenAuxiliary, .moveToActiveSpace]
    }

    private func updateWindowBehavior() {
        panel?.collectionBehavior = collectionBehavior
        panel?.hidesOnDeactivate = false
        panel?.canHide = false
        updateWindowLevel()
        clampToVisibleScreen()
    }

    func setScreenCaptureExclusion(_ isExcluded: Bool) {
        excludeFromScreenCapture = isExcluded
        panel?.sharingType = isExcluded ? .none : .readOnly
    }

    func windowDidMove(_: Notification) {
        scheduleClampToVisibleScreen()
    }

    func windowDidResize(_: Notification) {
        scheduleClampToVisibleScreen()
    }

    func windowWillClose(_: Notification) {
        panel = nil
        isVisible = false
    }

    private func scheduleClampToVisibleScreen() {
        guard !isClampingFrame else { return }
        DispatchQueue.main.async { [weak self] in
            self?.clampToVisibleScreen()
        }
    }

    private func clampToVisibleScreen() {
        guard let panel else { return }
        guard !isClampingFrame else { return }

        let frame = panel.frame
        let screen = screen(containing: frame) ?? NSScreen.main ?? NSScreen.screens.first
        guard let visibleFrame = screen?.visibleFrame else { return }

        let maxX = visibleFrame.maxX - frame.width - screenMargin
        let maxY = visibleFrame.maxY - frame.height - screenMargin
        let minX = visibleFrame.minX + screenMargin
        let minY = visibleFrame.minY + screenMargin

        let clampedX = min(max(frame.origin.x, minX), maxX)
        let clampedY = min(max(frame.origin.y, minY), maxY)
        let clampedOrigin = NSPoint(x: clampedX, y: clampedY)

        guard clampedOrigin != frame.origin else { return }
        isClampingFrame = true
        panel.setFrameOrigin(clampedOrigin)
        isClampingFrame = false
    }

    private func screen(containing frame: NSRect) -> NSScreen? {
        let center = NSPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.first { $0.frame.contains(center) }
            ?? NSScreen.screens.first { $0.frame.intersects(frame) }
    }
}

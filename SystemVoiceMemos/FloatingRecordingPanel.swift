import AppKit
import SwiftUI

@MainActor
final class FloatingRecordingPanel: NSObject, ObservableObject, NSWindowDelegate {
    private let fullPanelSize = NSSize(width: 408, height: 88)
    private let compactPanelSize = NSSize(width: 198, height: 64)
    private let screenMargin: CGFloat = 10

    private var panel: NSPanel?
    private var recorder: SystemAudioRecorder?
    private var isClampingFrame = false

    @Published var isVisible = false
    @AppStorage("minimalRecordingAlwaysOnTop") var isAlwaysOnTop = true
    @AppStorage("minimalRecordingCompactMode") var isCompact = false
    @AppStorage(AppConstants.UserDefaultsKeys.hideFromScreenSharing) private var excludeFromScreenCapture = true

    var onStop: (() -> Void)?
    var onRestart: (() -> Void)?
    var onExpand: (() -> Void)?

    /// Displays the floating recording panel for the given recorder and makes it visible.
    /// - Parameter recorder: The `SystemAudioRecorder` instance to associate with the panel; its state is shown and controlled by the panel.
    func show(recorder: SystemAudioRecorder) {
        self.recorder = recorder

        if panel == nil {
            createPanel()
        }

        updatePanelSize()
        updateWindowBehavior()
        updateContent()
        clampToVisibleScreen()
        panel?.orderFrontRegardless()
        isVisible = true
    }

    /// Hides the floating recording panel and updates the published visibility state.
    /// 
    /// The panel is ordered out but not closed or released, allowing it to be shown again later.
    func hide() {
        panel?.orderOut(nil)
        isVisible = false
    }

    /// Closes the floating panel and clears the panel-related state.
    /// 
    /// If a panel exists, removes its delegate, closes the window, sets the stored `panel` to `nil`, and updates `isVisible` to `false`.
    func close() {
        panel?.delegate = nil
        panel?.close()
        panel = nil
        isVisible = false
    }

    /// Creates and configures the floating `NSPanel` used to host the recording UI and assigns it to `self.panel`.
    /// 
    /// The panel is configured for non-activating, borderless presentation, floating behavior, screen-sharing exclusion when requested, and an initial on-screen position near the bottom center of the main screen. The panel's delegate is set to `self` and its level and collection behavior are initialized.
    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: currentPanelSize),
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
            let x = screenFrame.midX - (currentPanelSize.width / 2)
            let y = screenFrame.minY + 80
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        self.panel = panel
    }

    /// Updates the panel's SwiftUI content to a `MinimalRecordingView` bound to the current recorder and UI state.
    /// 
    /// If the panel or recorder is not available, the method has no effect. The view receives bindings that:
    /// - update window behavior when `isAlwaysOnTop` changes, and
    /// - resize, clamp to the visible screen, and refresh the hosted content when `isCompact` changes.
    /// The `MinimalRecordingView` is hosted in an `NSHostingView` sized to the panel's content bounds.
    private func updateContent() {
        guard let panel = panel, let recorder = recorder else { return }

        let isOnTopBinding = Binding<Bool>(
            get: { [weak self] in self?.isAlwaysOnTop ?? true },
            set: { [weak self] newValue in
                self?.isAlwaysOnTop = newValue
                self?.updateWindowBehavior()
            }
        )
        let isCompactBinding = Binding<Bool>(
            get: { [weak self] in self?.isCompact ?? false },
            set: { [weak self] newValue in
                guard let self else { return }
                self.isCompact = newValue
                self.updatePanelSize()
                self.clampToVisibleScreen()
                self.updateContent()
            }
        )

        let contentView = MinimalRecordingView(
            recorder: recorder,
            isAlwaysOnTop: isOnTopBinding,
            isCompact: isCompactBinding,
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

    /// Updates the panel's window level to match the current always-on-top setting.
    /// When `isAlwaysOnTop` is true the panel is placed at the `.statusBar` level; otherwise it is set to `.normal`.
    private func updateWindowLevel() {
        panel?.level = isAlwaysOnTop ? .statusBar : .normal
    }

    private var currentPanelSize: NSSize {
        isCompact ? compactPanelSize : fullPanelSize
    }

    /// Resize the panel to the current preferred size while preserving its on-screen center.
    /// 
    /// If there is no panel or the panel already matches the preferred size, this method does nothing. The panel's origin is adjusted so the panel remains centered on its previous midpoint.
    private func updatePanelSize() {
        guard let panel else { return }

        let oldFrame = panel.frame
        let newSize = currentPanelSize
        guard oldFrame.size != newSize else { return }

        let newOrigin = NSPoint(
            x: oldFrame.midX - newSize.width / 2,
            y: oldFrame.midY - newSize.height / 2
        )
        panel.setFrame(NSRect(origin: newOrigin, size: newSize), display: true)
    }

    private var collectionBehavior: NSWindow.CollectionBehavior {
        if isAlwaysOnTop {
            return [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        }
        return [.canJoinAllSpaces, .fullScreenAuxiliary, .moveToActiveSpace]
    }

    /// Updates the panel's window behavior to match current settings, refreshes its window level, and re-clamps the panel frame to the visible screen.
    /// 
    /// This sets `collectionBehavior`, `hidesOnDeactivate`, and `canHide`, then calls `updateWindowLevel()` and `clampToVisibleScreen()`.
    private func updateWindowBehavior() {
        panel?.collectionBehavior = collectionBehavior
        panel?.hidesOnDeactivate = false
        panel?.canHide = false
        updateWindowLevel()
        clampToVisibleScreen()
    }

    /// Toggle whether the floating panel is excluded from screen capture.
    /// - Parameter isExcluded: `true` to exclude the panel from screen sharing (sets the panel's `sharingType` to `.none`), `false` to allow read-only sharing (sets the panel's `sharingType` to `.readOnly`).
    func setScreenCaptureExclusion(_ isExcluded: Bool) {
        excludeFromScreenCapture = isExcluded
        panel?.sharingType = isExcluded ? .none : .readOnly
    }

    /// Invoked when the window moves to ensure the panel is repositioned inside the visible screen bounds.
    /// 
    /// This schedules a clamp operation that will adjust the panel's frame if needed to keep it within the current screen's visible area.
    func windowDidMove(_: Notification) {
        scheduleClampToVisibleScreen()
    }

    /// Schedules a clamp operation to keep the panel within the visible screen when the window is resized.
    /// - Parameter _: The resize notification (unused).
    func windowDidResize(_: Notification) {
        scheduleClampToVisibleScreen()
    }

    /// Called when the panel is about to close; clears the stored panel reference and marks the panel as not visible.
    /// - Note: The incoming `Notification` is unused.
    func windowWillClose(_: Notification) {
        panel = nil
        isVisible = false
    }

    /// Schedules a deferred clamping of the panel's frame to the visible screen bounds.
    /// - Note: If a clamp is already in progress, this is a no-op. The actual clamp is enqueued to run on the main queue on the next run loop cycle.
    private func scheduleClampToVisibleScreen() {
        guard !isClampingFrame else { return }
        DispatchQueue.main.async { [weak self] in
            self?.clampToVisibleScreen()
        }
    }

    /// Ensures the panel's origin lies within the current screen's visible area plus the configured margin, moving the panel if necessary.
    /// 
    /// If the panel is outside the visible bounds of its containing screen, adjusts its origin so the entire panel fits within the screen's visibleFrame inset by `screenMargin`. Temporarily sets `isClampingFrame` to prevent re-entrant frame adjustments while repositioning the panel. Does nothing if the panel is already within the allowed area or if no screen is available.
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

    /// Selects the screen whose frame contains the center of the given rectangle, or if none, the first screen that intersects it.
    /// - Parameter frame: The rectangle (in global screen coordinates) to locate.
    /// - Returns: The matching `NSScreen` if found, or `nil` when no screen contains or intersects the rectangle.
    private func screen(containing frame: NSRect) -> NSScreen? {
        let center = NSPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.first { $0.frame.contains(center) }
            ?? NSScreen.screens.first { $0.frame.intersects(frame) }
    }
}

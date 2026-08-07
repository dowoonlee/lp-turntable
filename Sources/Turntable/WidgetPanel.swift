import AppKit

final class WidgetPanel: NSPanel {
    /// Supplies the right-click menu. Handled here in AppKit rather than with SwiftUI's
    /// `.contextMenu`, which does not fire on a non-activating borderless panel.
    var contextMenuProvider: (() -> NSMenu)?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        titlebarAppearsTransparent = true
        titleVisibility = .hidden

        isMovableByWindowBackground = true
        isReleasedWhenClosed = false

        let size = TurntableView.panelSize
        minSize = size
        maxSize = size
        setContentSize(size)

        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        setFrameAutosaveName("TurntablePanel")

        updateAlwaysOnTop(Preferences.shared.alwaysOnTop)
        updateOpacity(Preferences.shared.opacity)
    }

    func updateAlwaysOnTop(_ enabled: Bool) {
        isFloatingPanel = enabled
        level = enabled ? .floating : .normal
    }

    func updateOpacity(_ value: Double) {
        alphaValue = value
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = contextMenuProvider?(), let view = contentView else {
            super.rightMouseDown(with: event)
            return
        }
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

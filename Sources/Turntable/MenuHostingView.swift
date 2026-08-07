import AppKit
import SwiftUI

/// Hosting view that answers right-clicks with an AppKit menu.
///
/// Two things rule out the simpler options: SwiftUI's `.contextMenu` does not fire on a
/// non-activating borderless panel, and the click never reaches `NSPanel.rightMouseDown`
/// because the hosting view consumes it first. Overriding here is what actually works.
final class MenuHostingView<Content: View>: NSHostingView<Content> {
    var menuProvider: (() -> NSMenu)?

    required init(rootView: Content) {
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = menuProvider?() else {
            super.rightMouseDown(with: event)
            return
        }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        menuProvider?() ?? super.menu(for: event)
    }
}

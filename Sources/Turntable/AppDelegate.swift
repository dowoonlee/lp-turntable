import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: WidgetPanel?
    private var statusBar: StatusBarController?
    private let monitor = NowPlayingMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let size = TurntableView.panelSize
        let panel = WidgetPanel(contentRect: NSRect(origin: .zero, size: size))
        let hostingView = MenuHostingView(
            rootView: TurntableView(monitor: monitor, theme: Preferences.shared.theme)
        )
        panel.contentView = hostingView

        if panel.setFrameUsingName(panel.frameAutosaveName) == false {
            panel.center()
        }
        panel.orderFrontRegardless()
        self.panel = panel

        let statusBar = StatusBarController(
            onToggleVisibility: { [weak panel] in
                guard let panel else { return }
                if panel.isVisible {
                    panel.orderOut(nil)
                } else {
                    panel.orderFrontRegardless()
                }
            },
            onToggleAlwaysOnTop: { [weak panel] enabled in
                panel?.updateAlwaysOnTop(enabled)
            },
            onSetOpacity: { [weak panel] value in
                panel?.updateOpacity(value)
            },
            // Rebuilding the root view rather than observing a store: the root's type stays
            // `TurntableView`, and SwiftUI treats this as an update of the same root, so the
            // arm's tilt state and the timelines survive the swap.
            onSetTheme: { [weak hostingView, monitor] theme in
                hostingView?.rootView = TurntableView(monitor: monitor, theme: theme)
            }
        )
        self.statusBar = statusBar
        let menuProvider = { [weak statusBar] in statusBar?.makeMenu() ?? NSMenu() }
        hostingView.menuProvider = menuProvider
        panel.contextMenuProvider = menuProvider

        monitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }
}

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
        let hostingView = MenuHostingView(rootView: TurntableView(monitor: monitor))
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

import AppKit

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let onToggleVisibility: () -> Void
    private let onToggleAlwaysOnTop: (Bool) -> Void
    private let onSetOpacity: (Double) -> Void

    init(onToggleVisibility: @escaping () -> Void,
         onToggleAlwaysOnTop: @escaping (Bool) -> Void,
         onSetOpacity: @escaping (Double) -> Void) {
        self.onToggleVisibility = onToggleVisibility
        self.onToggleAlwaysOnTop = onToggleAlwaysOnTop
        self.onSetOpacity = onSetOpacity

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let image = NSImage(
            systemSymbolName: "opticaldisc",
            accessibilityDescription: "Turntable"
        )
        statusItem.button?.image = image
        statusItem.menu = makeMenu()
    }

    /// Also used for the widget's right-click menu, since the status item can be
    /// dropped by macOS when the menu bar is full.
    func makeMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(
            withTitle: "위젯 보이기 / 숨기기",
            action: #selector(toggleVisibility),
            keyEquivalent: ""
        ).target = self

        let onTop = NSMenuItem(
            title: "항상 위에 표시",
            action: #selector(toggleAlwaysOnTop),
            keyEquivalent: ""
        )
        onTop.target = self
        onTop.state = Preferences.shared.alwaysOnTop ? .on : .off
        menu.addItem(onTop)

        let opacity = NSMenuItem(title: "투명도", action: nil, keyEquivalent: "")
        opacity.submenu = makeOpacityMenu()
        menu.addItem(opacity)

        menu.addItem(.separator())

        menu.addItem(
            withTitle: "종료",
            action: #selector(quit),
            keyEquivalent: "q"
        ).target = self

        return menu
    }

    private func makeOpacityMenu() -> NSMenu {
        let menu = NSMenu()
        let current = Preferences.shared.opacity

        for value in Preferences.opacityChoices {
            let title = value >= 1 ? "불투명" : "\(Int(value * 100))%"
            let item = NSMenuItem(title: title,
                                  action: #selector(setOpacity(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = value
            item.state = abs(current - value) < 0.005 ? .on : .off
            menu.addItem(item)
        }
        return menu
    }

    @objc private func toggleVisibility() {
        onToggleVisibility()
    }

    @objc private func setOpacity(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        Preferences.shared.opacity = value
        onSetOpacity(value)
        // The status item keeps one long-lived menu, so rebuild it to move the checkmark.
        statusItem.menu = makeMenu()
    }

    @objc private func toggleAlwaysOnTop(_ sender: NSMenuItem) {
        let enabled = !Preferences.shared.alwaysOnTop
        Preferences.shared.alwaysOnTop = enabled
        sender.state = enabled ? .on : .off
        onToggleAlwaysOnTop(enabled)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

import Foundation

final class Preferences {
    static let shared = Preferences()

    private enum Key {
        static let alwaysOnTop = "alwaysOnTop"
        static let opacity = "opacity"
        static let theme = "theme"
    }

    /// Offered in the menu. Floored well above zero so the widget can never be made
    /// invisible — with no reliable menu bar item, that would strand it.
    static let opacityChoices: [Double] = [1.0, 0.9, 0.75, 0.6, 0.45]

    private let defaults = UserDefaults.standard

    /// Set by `TURNTABLE_THEME` so a skin can be screenshotted without reinstalling.
    /// Held in memory instead of written through, so the stored choice survives the run —
    /// and picking from the menu clears it, which keeps the checkmark honest.
    private var themeOverride: Theme?

    private init() {
        defaults.register(defaults: [
            Key.alwaysOnTop: true,
            Key.opacity: 1.0,
            Key.theme: Theme.walnut.id
        ])

        if let forced = ProcessInfo.processInfo.environment["TURNTABLE_THEME"] {
            themeOverride = Theme.named(forced)
        }
    }

    var alwaysOnTop: Bool {
        get { defaults.bool(forKey: Key.alwaysOnTop) }
        set { defaults.set(newValue, forKey: Key.alwaysOnTop) }
    }

    var opacity: Double {
        get {
            let stored = defaults.double(forKey: Key.opacity)
            guard let lowest = Self.opacityChoices.min() else { return 1 }
            return stored >= lowest ? min(1, stored) : 1
        }
        set { defaults.set(newValue, forKey: Key.opacity) }
    }

    /// Falls back to the default skin for an unknown id, the way `opacity` clamps an
    /// out-of-range value — the key is writable by hand via `defaults write`.
    var theme: Theme {
        get {
            if let themeOverride { return themeOverride }
            let id = defaults.string(forKey: Key.theme) ?? Theme.walnut.id
            return Theme.named(id) ?? .walnut
        }
        set {
            themeOverride = nil
            defaults.set(newValue.id, forKey: Key.theme)
        }
    }
}

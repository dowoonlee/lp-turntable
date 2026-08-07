import Foundation

final class Preferences {
    static let shared = Preferences()

    private enum Key {
        static let alwaysOnTop = "alwaysOnTop"
        static let opacity = "opacity"
    }

    /// Offered in the menu. Floored well above zero so the widget can never be made
    /// invisible — with no reliable menu bar item, that would strand it.
    static let opacityChoices: [Double] = [1.0, 0.9, 0.75, 0.6, 0.45]

    private let defaults = UserDefaults.standard

    private init() {
        defaults.register(defaults: [
            Key.alwaysOnTop: true,
            Key.opacity: 1.0
        ])
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
}

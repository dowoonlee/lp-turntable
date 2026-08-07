import SwiftUI

/// How the tonearm is built, not just how it is painted.
enum ArmStyle: Equatable {
    /// Pivoted arm swinging about a bearing. `curve` is the lateral swell of the tube:
    /// 0 draws it dead straight, positive bends it into the S every DJ deck has.
    ///
    /// The bend is drawn symmetrically so the stylus stays on the pivot's downward axis.
    /// A real S-arm offsets the headshell as well, but the tracking geometry here is solved
    /// from the pivot→stylus straight-line distance — bending that axis would put the
    /// needle somewhere the law of cosines never asked for.
    case pivoted(curve: CGFloat)

    /// Linear tracker: the stylus rides a rail straight in toward the spindle, the way
    /// the groove was cut. No swing, so the arm has no angle to solve at all.
    case linear
}

/// Controls bolted to the plinth, beside the platter.
enum DeckHardware: Equatable {
    case none
    /// Pitch fader and a start/stop button — the SL-1200 layout, moved to the left because
    /// the tonearm owns the right side of a panel this small.
    case djConsole
    /// One rotary control, the way a deck that hides its controls does it.
    case rotaryKnob
    /// Lit strip along the bottom edge.
    case glowStrip
}

/// How the record itself is drawn.
enum DiscStyle: Equatable {
    /// Album art fills the whole record. `innerRatio` is where the grooves stop, as a
    /// fraction of the diameter — the tonearm finishes on that ring.
    case fullFace(innerRatio: CGFloat)

    /// Black vinyl with the art shrunk to a centre label, the way a pressing actually
    /// looks. `ratio` is the label diameter as a fraction of the record's.
    case centerLabel(ratio: CGFloat)
}

/// One skin: palette *and* form.
///
/// Panel size stays out of it. The panel locks its size to `TurntableView.panelSize` and
/// restores a saved frame by autosave name, so a theme that resized the window would have
/// to drag both of those paths along with it. Everything inside the panel is fair game —
/// platter diameter included, since the arm derives its length from the pivot and solves
/// its angle from whatever radius the record actually has.
struct Theme: Identifiable, Equatable {
    let id: String
    /// Shown in the menu.
    let name: String

    // MARK: Form

    var armStyle: ArmStyle
    var armTubeWidth: CGFloat
    var counterweightWidth: CGFloat
    /// The little outrigger weight beside the bearing. Deck-specific hardware, so it is
    /// a flag rather than a size.
    var hasAntiSkate: Bool

    var discStyle: DiscStyle
    var platterDiameter: CGFloat
    /// Mat diameter as a multiple of the record's. Wide enough and the mat becomes a
    /// visible ring around the disc, which is where the strobe dots live.
    var platterRingRatio: CGFloat
    var hasStrobe: Bool

    var grooveCount: Int
    var grooveOuterInset: Double

    /// Turns per minute. 33⅓ is 200°/s; a 45 spins half again as fast, which is the one
    /// difference between skins you notice without looking at the widget directly.
    var rpm: Double
    /// Spindle hole diameter, as a fraction of the record's. A 45 punches a wide one.
    var spindleRatio: CGFloat
    var deckHardware: DeckHardware

    // MARK: Deck

    /// Three stops, top to bottom.
    var deckGradient: [Color]
    var deckBorder: Color
    var plinthRing: Color

    // Platter — the mat the record sits on
    var platterInner: Color
    var platterOuter: Color
    var strobeColor: Color

    // Disc
    var grooveTint: Color
    var grooveStrongOpacity: Double
    var grooveFaintOpacity: Double
    /// `.multiply` darkens art from underneath; black vinyl instead needs grooves that
    /// catch the light, which only reads with a normal blend and a pale tint.
    var grooveBlend: BlendMode
    /// The record itself, wherever the art does not cover it.
    var vinylColor: Color
    /// Two stops, used when the track has no artwork.
    var artworkFallback: [Color]

    // Chrome
    var rimShade: Color
    var edgeDark: Color
    var edgeHighlight: Color
    var sheenColor: Color
    /// Scales the sheen's built-in opacities. 1 leaves them as drawn.
    var sheenIntensity: Double
    var spindleOuter: Color
    var spindleInner: Color
    /// Lit parts of the deck hardware — strobe lamp, glow strip, knob indicator.
    var controlAccent: Color

    // Tonearm
    /// Three stops, across the tube.
    var armMetal: [Color]
    var counterweight: [Color]
    var headshell: [Color]
    var armRestPost: [Color]
    var armRestCradle: Color

    // Text
    var titleColor: Color
    var subtitleColor: Color
    var mutedColor: Color
    var noticeColor: Color

    /// Scales every drop shadow at once. Light decks need less of them — a shadow tuned
    /// for near-black reads as a smudge on off-white.
    var shadowStrength: Double

    /// Radius of the last groove, as a fraction of the diameter. The arm finishes here, so
    /// redrawing the record moves where the needle lands without touching the geometry.
    var innermostGrooveRatio: Double {
        switch discStyle {
        case .fullFace(let ratio):
            return Double(ratio)
        case .centerLabel(let ratio):
            // Grooves run up to the label edge, with a hair of run-out between.
            return Double(ratio) / 2 + 0.025
        }
    }

    /// Inset of the innermost groove from the edge, which is what the groove stack draws with.
    var grooveInnerInset: Double { 0.5 - innermostGrooveRatio }

    var isLinearTracked: Bool { armStyle == .linear }

    /// Degrees the platter turns per second.
    var degreesPerSecond: Double { rpm * 6 }

    static let all: [Theme] = [.walnut, .technics, .braun, .midnight, .single45]

    static func named(_ id: String) -> Theme? {
        all.first { $0.id == id }
    }
}

// MARK: - Skins

extension Theme {
    /// The original deck: dark wood plinth, straight chrome arm, art across the whole record.
    static let walnut = Theme(
        id: "walnut",
        name: "월넛",
        armStyle: .pivoted(curve: 0),
        armTubeWidth: 3,
        counterweightWidth: 12,
        hasAntiSkate: false,
        discStyle: .fullFace(innerRatio: 0.11),
        platterDiameter: 134,
        platterRingRatio: 1.06,
        hasStrobe: false,
        grooveCount: 24,
        grooveOuterInset: 0.015,
        rpm: 33 + 1.0 / 3,
        spindleRatio: 0.055,
        deckHardware: .none,
        deckGradient: [
            Color(red: 0.19, green: 0.15, blue: 0.13),
            Color(red: 0.12, green: 0.09, blue: 0.08),
            Color(red: 0.07, green: 0.06, blue: 0.05)
        ],
        deckBorder: .white.opacity(0.08),
        plinthRing: .white.opacity(0.05),
        platterInner: Color(white: 0.20),
        platterOuter: Color(white: 0.08),
        strobeColor: .clear,
        grooveTint: .black,
        grooveStrongOpacity: 0.30,
        grooveFaintOpacity: 0.17,
        grooveBlend: .multiply,
        vinylColor: Color(white: 0.07),
        artworkFallback: [
            Color(red: 0.30, green: 0.20, blue: 0.18),
            Color(red: 0.14, green: 0.10, blue: 0.09)
        ],
        rimShade: .black.opacity(0.50),
        edgeDark: .black.opacity(0.55),
        edgeHighlight: .white.opacity(0.12),
        sheenColor: .white,
        sheenIntensity: 1.0,
        spindleOuter: .black.opacity(0.75),
        spindleInner: Color(white: 0.72),
        controlAccent: Color(red: 0.85, green: 0.45, blue: 0.25),
        armMetal: [Color(white: 0.88), Color(white: 0.55), Color(white: 0.78)],
        counterweight: [Color(white: 0.30), Color(white: 0.14)],
        headshell: [Color(white: 0.82), Color(white: 0.48)],
        armRestPost: [Color(white: 0.36), Color(white: 0.15)],
        armRestCradle: .black.opacity(0.60),
        titleColor: .white.opacity(0.95),
        subtitleColor: .white.opacity(0.55),
        mutedColor: .white.opacity(0.45),
        noticeColor: .white.opacity(0.85),
        shadowStrength: 1.0
    )

    /// Technics SL-1200MK2: silver cabinet, S-shaped arm with an anti-skate outrigger,
    /// black vinyl on a wide mat ringed with strobe dots.
    static let technics = Theme(
        id: "technics",
        name: "테크닉스 실버",
        armStyle: .pivoted(curve: 11),
        armTubeWidth: 3.4,
        counterweightWidth: 13,
        hasAntiSkate: true,
        discStyle: .centerLabel(ratio: 0.34),
        // Smaller record on a wider mat: the strobe dots need an exposed ring to sit in,
        // and the mat still has to clear the tonearm pivot at x=175.
        platterDiameter: 118,
        platterRingRatio: 1.20,
        hasStrobe: true,
        grooveCount: 34,
        grooveOuterInset: 0.012,
        rpm: 33 + 1.0 / 3,
        spindleRatio: 0.055,
        deckHardware: .djConsole,
        deckGradient: [
            Color(red: 0.76, green: 0.76, blue: 0.77),
            Color(red: 0.66, green: 0.66, blue: 0.68),
            Color(red: 0.55, green: 0.55, blue: 0.57)
        ],
        deckBorder: .black.opacity(0.18),
        plinthRing: .black.opacity(0.12),
        platterInner: Color(white: 0.30),
        platterOuter: Color(white: 0.16),
        strobeColor: Color(white: 0.86),
        grooveTint: .white,
        grooveStrongOpacity: 0.16,
        grooveFaintOpacity: 0.07,
        grooveBlend: .normal,
        vinylColor: Color(white: 0.07),
        artworkFallback: [Color(white: 0.34), Color(white: 0.18)],
        rimShade: .black.opacity(0.40),
        edgeDark: .black.opacity(0.60),
        edgeHighlight: .white.opacity(0.14),
        sheenColor: .white,
        sheenIntensity: 1.1,
        spindleOuter: .black.opacity(0.70),
        spindleInner: Color(white: 0.80),
        controlAccent: Color(red: 0.90, green: 0.20, blue: 0.16),
        armMetal: [Color(white: 0.93), Color(white: 0.66), Color(white: 0.85)],
        counterweight: [Color(white: 0.28), Color(white: 0.12)],
        headshell: [Color(white: 0.88), Color(white: 0.55)],
        // Darker than the arm it holds: on a light deck a silver rest disappears into
        // the plinth, and the rest is the only thing that reads as "stopped".
        armRestPost: [Color(white: 0.46), Color(white: 0.26)],
        armRestCradle: .black.opacity(0.55),
        titleColor: .black.opacity(0.88),
        subtitleColor: .black.opacity(0.60),
        mutedColor: .black.opacity(0.50),
        noticeColor: .black.opacity(0.80),
        shadowStrength: 0.70
    )

    /// Braun SK4 — white sheet metal and beech, with the thinnest arm of the four.
    /// The light-deck case the text tokens exist for.
    static let braun = Theme(
        id: "braun",
        name: "브라운 화이트",
        armStyle: .pivoted(curve: 0),
        armTubeWidth: 1.8,
        counterweightWidth: 8,
        hasAntiSkate: false,
        discStyle: .centerLabel(ratio: 0.30),
        platterDiameter: 120,
        platterRingRatio: 1.10,
        hasStrobe: false,
        grooveCount: 30,
        grooveOuterInset: 0.014,
        rpm: 33 + 1.0 / 3,
        spindleRatio: 0.050,
        deckHardware: .rotaryKnob,
        deckGradient: [
            Color(red: 0.95, green: 0.94, blue: 0.91),
            Color(red: 0.90, green: 0.89, blue: 0.85),
            Color(red: 0.83, green: 0.81, blue: 0.76)
        ],
        deckBorder: .black.opacity(0.14),
        plinthRing: .black.opacity(0.10),
        platterInner: Color(white: 0.86),
        platterOuter: Color(white: 0.72),
        strobeColor: .clear,
        grooveTint: .white,
        grooveStrongOpacity: 0.14,
        grooveFaintOpacity: 0.06,
        grooveBlend: .normal,
        vinylColor: Color(white: 0.09),
        artworkFallback: [
            Color(red: 0.80, green: 0.76, blue: 0.70),
            Color(red: 0.62, green: 0.58, blue: 0.52)
        ],
        rimShade: .black.opacity(0.35),
        edgeDark: .black.opacity(0.45),
        edgeHighlight: .white.opacity(0.25),
        sheenColor: .white,
        sheenIntensity: 0.90,
        spindleOuter: .black.opacity(0.55),
        spindleInner: Color(white: 0.88),
        controlAccent: Color(red: 0.86, green: 0.62, blue: 0.16),
        armMetal: [Color(white: 0.95), Color(white: 0.72), Color(white: 0.88)],
        counterweight: [Color(white: 0.35), Color(white: 0.18)],
        headshell: [Color(white: 0.92), Color(white: 0.62)],
        armRestPost: [Color(white: 0.52), Color(white: 0.30)],
        armRestCradle: .black.opacity(0.55),
        titleColor: .black.opacity(0.85),
        subtitleColor: .black.opacity(0.55),
        mutedColor: .black.opacity(0.45),
        noticeColor: .black.opacity(0.78),
        shadowStrength: 0.55
    )

    /// Near-black deck lit by cyan and magenta, tracked by a rail instead of a pivot.
    static let midnight = Theme(
        id: "midnight",
        name: "미드나잇",
        armStyle: .linear,
        armTubeWidth: 3,
        counterweightWidth: 12,
        hasAntiSkate: false,
        discStyle: .fullFace(innerRatio: 0.13),
        platterDiameter: 130,
        platterRingRatio: 1.05,
        hasStrobe: false,
        grooveCount: 18,
        grooveOuterInset: 0.018,
        rpm: 33 + 1.0 / 3,
        spindleRatio: 0.055,
        deckHardware: .glowStrip,
        deckGradient: [
            Color(red: 0.07, green: 0.07, blue: 0.11),
            Color(red: 0.04, green: 0.04, blue: 0.07),
            Color(red: 0.02, green: 0.02, blue: 0.04)
        ],
        deckBorder: Color(red: 0.35, green: 0.85, blue: 0.95).opacity(0.28),
        plinthRing: Color(red: 0.85, green: 0.30, blue: 0.75).opacity(0.22),
        platterInner: Color(red: 0.10, green: 0.10, blue: 0.16),
        platterOuter: Color(red: 0.03, green: 0.03, blue: 0.06),
        strobeColor: .clear,
        grooveTint: .black,
        grooveStrongOpacity: 0.32,
        grooveFaintOpacity: 0.18,
        grooveBlend: .multiply,
        vinylColor: Color(red: 0.04, green: 0.04, blue: 0.08),
        artworkFallback: [
            Color(red: 0.16, green: 0.08, blue: 0.28),
            Color(red: 0.05, green: 0.04, blue: 0.12)
        ],
        rimShade: .black.opacity(0.55),
        edgeDark: .black.opacity(0.60),
        edgeHighlight: Color(red: 0.45, green: 0.90, blue: 1.00).opacity(0.30),
        sheenColor: Color(red: 0.55, green: 0.90, blue: 1.00),
        sheenIntensity: 1.30,
        spindleOuter: .black.opacity(0.75),
        spindleInner: Color(red: 0.60, green: 0.92, blue: 1.00),
        controlAccent: Color(red: 0.45, green: 0.92, blue: 1.00),
        armMetal: [
            Color(red: 0.72, green: 0.86, blue: 0.92),
            Color(red: 0.36, green: 0.48, blue: 0.58),
            Color(red: 0.60, green: 0.78, blue: 0.88)
        ],
        counterweight: [
            Color(red: 0.22, green: 0.18, blue: 0.30),
            Color(red: 0.09, green: 0.07, blue: 0.14)
        ],
        headshell: [
            Color(red: 0.70, green: 0.84, blue: 0.92),
            Color(red: 0.32, green: 0.42, blue: 0.52)
        ],
        armRestPost: [
            Color(red: 0.30, green: 0.36, blue: 0.46),
            Color(red: 0.12, green: 0.14, blue: 0.20)
        ],
        armRestCradle: .black.opacity(0.65),
        titleColor: Color(red: 0.90, green: 0.97, blue: 1.00).opacity(0.95),
        subtitleColor: Color(red: 0.55, green: 0.85, blue: 0.95).opacity(0.70),
        mutedColor: Color(red: 0.55, green: 0.85, blue: 0.95).opacity(0.50),
        noticeColor: Color(red: 0.90, green: 0.97, blue: 1.00).opacity(0.85),
        shadowStrength: 1.10
    )

    /// A 7-inch single on a portable: small record, wide donut hole, translucent orange
    /// vinyl, and the only skin that runs at 45 — half again the rotation speed, which is
    /// the one difference you catch out of the corner of your eye.
    static let single45 = Theme(
        id: "single45",
        name: "45 싱글",
        armStyle: .pivoted(curve: 0),
        armTubeWidth: 3.6,
        counterweightWidth: 11,
        hasAntiSkate: false,
        // Proportions off a real 7-inch: a 1.5" hole in a 3.5" label on a 7" record.
        // Any wider a hole and the label is a ring too thin to show the art at all.
        discStyle: .centerLabel(ratio: 0.50),
        platterDiameter: 108,
        platterRingRatio: 1.16,
        hasStrobe: false,
        grooveCount: 20,
        grooveOuterInset: 0.016,
        rpm: 45,
        spindleRatio: 0.19,
        deckHardware: .rotaryKnob,
        // Mint, so the orange vinyl has something to sit against.
        deckGradient: [
            Color(red: 0.76, green: 0.85, blue: 0.79),
            Color(red: 0.65, green: 0.76, blue: 0.70),
            Color(red: 0.53, green: 0.64, blue: 0.58)
        ],
        deckBorder: .black.opacity(0.16),
        plinthRing: .black.opacity(0.11),
        // Pale mat on purpose: translucent vinyl only reads as translucent if there is
        // something bright behind it to glow through.
        platterInner: Color(red: 0.95, green: 0.94, blue: 0.89),
        platterOuter: Color(red: 0.83, green: 0.82, blue: 0.75),
        strobeColor: .clear,
        grooveTint: .white,
        grooveStrongOpacity: 0.22,
        grooveFaintOpacity: 0.10,
        grooveBlend: .normal,
        vinylColor: Color(red: 0.88, green: 0.34, blue: 0.09).opacity(0.86),
        artworkFallback: [
            Color(red: 0.92, green: 0.62, blue: 0.30),
            Color(red: 0.72, green: 0.34, blue: 0.14)
        ],
        rimShade: .black.opacity(0.30),
        edgeDark: .black.opacity(0.42),
        edgeHighlight: .white.opacity(0.30),
        sheenColor: .white,
        sheenIntensity: 1.0,
        // The hole shows the mat through it, so it is painted the mat's colour.
        spindleOuter: Color(red: 0.88, green: 0.87, blue: 0.81),
        spindleInner: Color(white: 0.55),
        controlAccent: Color(red: 0.88, green: 0.34, blue: 0.09),
        armMetal: [Color(white: 0.90), Color(white: 0.60), Color(white: 0.80)],
        counterweight: [Color(white: 0.32), Color(white: 0.16)],
        headshell: [Color(white: 0.86), Color(white: 0.52)],
        armRestPost: [Color(white: 0.50), Color(white: 0.28)],
        armRestCradle: .black.opacity(0.55),
        titleColor: .black.opacity(0.86),
        subtitleColor: .black.opacity(0.56),
        mutedColor: .black.opacity(0.46),
        noticeColor: .black.opacity(0.80),
        shadowStrength: 0.65
    )
}

// MARK: - Environment

/// Passed through the environment rather than as a parameter. The deck builds the platter,
/// disc, chrome and arm as siblings, and `TurntableView` also instantiates `TonearmView`
/// twice purely to read `stylusDistance` off it — those geometry-only instances would
/// otherwise have to be handed a palette they never draw with.
private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.walnut
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

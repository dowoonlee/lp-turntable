import SwiftUI

/// The record is split into three layers so only the middle one has to be rebuilt
/// every animation frame. The mat sits behind the disc, the chrome (rim, edge, sheen,
/// spindle) in front of it, and both are static.

struct VinylPlatter: View {
    /// Diameter of the record. The mat is drawn as a multiple of it.
    let diameter: CGFloat

    @Environment(\.theme) private var theme

    private static let strobeDots = 44

    private var matDiameter: CGFloat { diameter * theme.platterRingRatio }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [theme.platterInner, theme.platterOuter],
                        center: .center,
                        startRadius: 0,
                        endRadius: matDiameter * 0.55
                    )
                )
                .frame(width: matDiameter, height: matDiameter)

            if theme.hasStrobe {
                strobe
            }
        }
        .shadow(color: .black.opacity(0.6 * theme.shadowStrength), radius: 10, y: 4)
    }

    /// Dots around the rim of the mat, in the band the record leaves uncovered. Lit by a
    /// mains-frequency lamp on a real deck they appear to stand still at the right speed;
    /// here they are simply what says "Technics" at a glance.
    private var strobe: some View {
        // Centre of the exposed ring: halfway between the record's edge and the mat's.
        let radius = diameter * (1 + theme.platterRingRatio) / 4
        return ForEach(0..<Self.strobeDots, id: \.self) { index in
            Circle()
                .fill(theme.strobeColor)
                .frame(width: 1.7, height: 1.7)
                .offset(y: -radius)
                .rotationEffect(.degrees(Double(index) / Double(Self.strobeDots) * 360))
        }
    }
}

/// The spinning disc: the album art, the grooves layered over it, and — on skins that press
/// their records properly — a centre label instead of art across the whole face.
struct VinylDisc: View {
    let artwork: NSImage?
    let rotation: Double
    let diameter: CGFloat

    @Environment(\.theme) private var theme

    var body: some View {
        // Rasterised once so each frame only re-composites a flat texture; rebuilding
        // the groove stack every frame costs several percent of a core.
        ZStack {
            face
            grooves
            if case .centerLabel(let ratio) = theme.discStyle {
                label(ratio: ratio)
            }
        }
        .drawingGroup()
        .rotationEffect(.degrees(rotation))
        .frame(width: diameter, height: diameter)
    }

    /// What the record is made of, under the grooves.
    @ViewBuilder
    private var face: some View {
        switch theme.discStyle {
        case .fullFace:
            artworkFill
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())
        case .centerLabel:
            Circle()
                .fill(
                    RadialGradient(
                        colors: [theme.vinylColor.opacity(0.92), theme.vinylColor],
                        center: .center,
                        startRadius: 0,
                        endRadius: diameter * 0.5
                    )
                )
                .frame(width: diameter, height: diameter)
        }
    }

    private var artworkFill: some View {
        Group {
            if let artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: theme.artworkFallback,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    /// Paper label the art shrinks onto. Drawn over the grooves rather than under them,
    /// since a label is glued on top of the pressing.
    private func label(ratio: CGFloat) -> some View {
        let size = diameter * ratio
        return artworkFill
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle().strokeBorder(Color.black.opacity(0.35), lineWidth: 0.8)
            )
    }

    /// Concentric rings across the playing surface. Dark and multiplied over album art;
    /// pale and normally blended over black vinyl, where the grooves are what catches
    /// the light rather than what blocks it.
    private var grooves: some View {
        ZStack {
            ForEach(0..<theme.grooveCount, id: \.self) { index in
                let t = Double(index) / Double(max(1, theme.grooveCount - 1))
                let inset = diameter
                    * (theme.grooveOuterInset
                       + (theme.grooveInnerInset - theme.grooveOuterInset) * t)
                let strong = index % 3 == 0
                Circle()
                    .strokeBorder(
                        theme.grooveTint.opacity(
                            strong ? theme.grooveStrongOpacity : theme.grooveFaintOpacity
                        ),
                        lineWidth: strong ? 1.0 : 0.6
                    )
                    .padding(inset)
            }
        }
        .blendMode(theme.grooveBlend)
    }
}

/// Everything that sits on top of the disc and does not rotate with it.
struct VinylChrome: View {
    let diameter: CGFloat

    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            rimShade
            edge
            sheen
            spindle
        }
        .frame(width: diameter, height: diameter)
    }

    /// Darkened run-out band at the rim, which is most of what sells "this is a record".
    private var rimShade: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [.clear, .clear, theme.rimShade],
                    center: .center,
                    startRadius: diameter * 0.38,
                    endRadius: diameter * 0.5
                )
            )
            .allowsHitTesting(false)
    }

    private var edge: some View {
        Circle()
            .strokeBorder(theme.edgeDark, lineWidth: 2)
            .overlay(
                Circle().strokeBorder(theme.edgeHighlight, lineWidth: 0.5)
            )
    }

    /// Models a fixed light source, so it must not rotate with the disc.
    private var sheen: some View {
        let clear = theme.sheenColor.opacity(0)
        return Circle()
            .fill(
                AngularGradient(
                    gradient: Gradient(stops: [
                        .init(color: clear, location: 0.00),
                        .init(color: sheenStop(0.13), location: 0.10),
                        .init(color: clear, location: 0.24),
                        .init(color: clear, location: 0.50),
                        .init(color: sheenStop(0.09), location: 0.60),
                        .init(color: clear, location: 0.74),
                        .init(color: clear, location: 1.00)
                    ]),
                    center: .center,
                    angle: .degrees(-35)
                )
            )
            .blendMode(.screen)
            .allowsHitTesting(false)
    }

    private func sheenStop(_ base: Double) -> Color {
        theme.sheenColor.opacity(min(1, base * theme.sheenIntensity))
    }

    /// The hole, and the post standing in it. A 45 punches a hole wide enough that it has
    /// to read as punched *through* — hence the rim shadow, which a 7pt LP hole never needs.
    private var spindle: some View {
        let hole = diameter * theme.spindleRatio
        let post = diameter * 0.028
        return ZStack {
            Circle()
                .fill(theme.spindleOuter)
                .frame(width: hole, height: hole)
                .overlay(
                    Circle().strokeBorder(Color.black.opacity(0.35), lineWidth: 1)
                )
            Circle()
                .fill(theme.spindleInner)
                .frame(width: post, height: post)
        }
    }
}

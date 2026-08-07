import SwiftUI

/// The record is split into three layers so only the middle one has to be rebuilt
/// every animation frame. The mat sits behind the disc, the chrome (rim, edge, sheen,
/// spindle) in front of it, and both are static.

struct VinylPlatter: View {
    let diameter: CGFloat

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color(white: 0.20), Color(white: 0.08)],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter * 0.58
                )
            )
            .frame(width: diameter * 1.06, height: diameter * 1.06)
            .shadow(color: .black.opacity(0.6), radius: 10, y: 4)
    }
}

/// The spinning disc: album art filling the whole record, with grooves layered on top.
struct VinylDisc: View {
    let artwork: NSImage?
    let rotation: Double
    let diameter: CGFloat

    /// Groove band, as an inset from the disc edge in fractions of the diameter.
    static let grooveOuterInset = 0.015
    static let grooveInnerInset = 0.390
    private static let grooveCount = 24

    /// Radius of the innermost groove ring, as a fraction of the diameter. The tonearm
    /// finishes here rather than at the spindle, so the stylus lands on the last groove.
    static let innermostGrooveRatio = 0.5 - grooveInnerInset

    var body: some View {
        // Rasterised once so each frame only re-composites a flat texture; rebuilding
        // the groove stack every frame costs several percent of a core.
        ZStack {
            artworkDisc
            grooves
        }
        .drawingGroup()
        .rotationEffect(.degrees(rotation))
        .frame(width: diameter, height: diameter)
    }

    private var artworkDisc: some View {
        Group {
            if let artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Color(red: 0.30, green: 0.20, blue: 0.18),
                             Color(red: 0.14, green: 0.10, blue: 0.09)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
    }

    private var grooves: some View {
        // Dark concentric rings over the art, stopping short of the spindle the way a
        // real pressing leaves its centre smooth.
        ZStack {
            ForEach(0..<Self.grooveCount, id: \.self) { index in
                let t = Double(index) / Double(Self.grooveCount - 1)
                let inset = diameter
                    * (Self.grooveOuterInset
                       + (Self.grooveInnerInset - Self.grooveOuterInset) * t)
                Circle()
                    .strokeBorder(
                        Color.black.opacity(index % 3 == 0 ? 0.30 : 0.17),
                        lineWidth: index % 3 == 0 ? 1.0 : 0.6
                    )
                    .padding(inset)
            }
        }
        .blendMode(.multiply)
    }
}

/// Everything that sits on top of the disc and does not rotate with it.
struct VinylChrome: View {
    let diameter: CGFloat

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
                    colors: [.clear, .clear, .black.opacity(0.5)],
                    center: .center,
                    startRadius: diameter * 0.38,
                    endRadius: diameter * 0.5
                )
            )
            .allowsHitTesting(false)
    }

    private var edge: some View {
        Circle()
            .strokeBorder(Color.black.opacity(0.55), lineWidth: 2)
            .overlay(
                Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
            )
    }

    /// Models a fixed light source, so it must not rotate with the disc.
    private var sheen: some View {
        Circle()
            .fill(
                AngularGradient(
                    gradient: Gradient(stops: [
                        .init(color: .white.opacity(0.00), location: 0.00),
                        .init(color: .white.opacity(0.13), location: 0.10),
                        .init(color: .white.opacity(0.00), location: 0.24),
                        .init(color: .white.opacity(0.00), location: 0.50),
                        .init(color: .white.opacity(0.09), location: 0.60),
                        .init(color: .white.opacity(0.00), location: 0.74),
                        .init(color: .white.opacity(0.00), location: 1.00)
                    ]),
                    center: .center,
                    angle: .degrees(-35)
                )
            )
            .blendMode(.screen)
            .allowsHitTesting(false)
    }

    private var spindle: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.75))
                .frame(width: diameter * 0.055, height: diameter * 0.055)
            Circle()
                .fill(Color(white: 0.72))
                .frame(width: diameter * 0.028, height: diameter * 0.028)
        }
    }
}

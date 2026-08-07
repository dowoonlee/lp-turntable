import SwiftUI

/// A linear tracker: the cartridge rides a rail straight in toward the spindle instead of
/// swinging on a bearing.
///
/// This is the one arm style with no angle to solve. A pivoted arm has to be aimed with the
/// law of cosines because its stylus travels an arc across a record whose grooves are
/// circles; a rail runs along the radius itself, so playback position maps to a distance and
/// nothing else. The parent hands over that distance as `carriage`.
struct LinearArmView: View {
    /// Rail length in points.
    let length: CGFloat
    /// 0 parks the carriage at the outer end, 1 takes it to the inner end.
    let carriage: Double
    /// 0 is tracking, 1 is fully lifted.
    let lift: Double
    /// Rail drawn past the inner end of the carriage's travel. A real tracker's rail runs
    /// over the spindle; ending it exactly where the carriage stops leaves a bar hanging
    /// in the middle of the record.
    var railOverhang: CGFloat = 0

    @Environment(\.theme) private var theme

    /// The parent positions by centre, so it needs the height up front.
    static let height: CGFloat = 26
    static let carriageWidth: CGFloat = 13
    /// How far the stylus tip sits below the view's centre. The parent lifts the whole
    /// assembly by this so the needle lands on the record's radius, not the rail.
    static let stylusOffset: CGFloat = 4.5

    private static let railGap: CGFloat = 4
    private static let cartridgeDrop: CGFloat = 7

    private var railY: CGFloat { Self.height * 0.30 }

    /// Travel stops half a carriage short of each end, leaving the end stops visible.
    private var span: CGFloat { length - Self.carriageWidth }

    private var totalWidth: CGFloat { length + railOverhang }

    private var metal: LinearGradient {
        LinearGradient(colors: theme.armMetal, startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        // Outer end is to the right: the record's rim is the far side from the spindle,
        // which the parent puts to the left.
        let x = totalWidth - Self.carriageWidth / 2 - CGFloat(carriage) * span

        return ZStack {
            rails
            endStop(at: 1.5)
            endStop(at: totalWidth - Self.carriageWidth / 2 + 1)
            carriageBlock
                .position(x: x, y: railY + CGFloat(lift) * 1.5)
        }
        .frame(width: totalWidth, height: Self.height)
    }

    /// Twin rails. A single bar reads as a stick lying across the record; two say "this
    /// thing slides".
    private var rails: some View {
        ForEach(0..<2, id: \.self) { index in
            Capsule()
                .fill(metal)
                .frame(width: totalWidth, height: 1.8)
                .position(x: totalWidth / 2, y: railY + CGFloat(index) * Self.railGap)
        }
    }

    private func endStop(at x: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(
                LinearGradient(colors: theme.armRestPost,
                               startPoint: .top,
                               endPoint: .bottom)
            )
            .frame(width: 3, height: Self.railGap + 7)
            .position(x: x, y: railY + Self.railGap / 2)
    }

    private var carriageBlock: some View {
        // The cartridge shortens as it lifts, for the same reason the pivoted arm's tube
        // does: seen from overhead, height is only legible as foreshortening.
        let drop = Self.cartridgeDrop * (1 - 0.5 * CGFloat(lift))

        return VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(metal)
                .frame(width: Self.carriageWidth, height: Self.railGap + 8)
                .overlay(
                    Circle()
                        .fill(theme.spindleInner)
                        .frame(width: 2.5, height: 2.5)
                        .offset(y: -2)
                )

            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(
                    LinearGradient(colors: theme.headshell,
                                   startPoint: .top,
                                   endPoint: .bottom)
                )
                .frame(width: 6, height: drop)
        }
        .shadow(color: .black.opacity(0.5 * theme.shadowStrength), radius: 2, y: 1)
    }
}

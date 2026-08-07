import SwiftUI

/// The tube, drawn from the pivot end down to the headshell.
///
/// `curve` bends it sideways without moving either end: both stay on the vertical axis
/// through the pivot, which is the line the tracking geometry solves along. A cubic gets
/// the S from two opposed control points, so the swell is roughly two thirds of `curve` —
/// the curve never reaches its handles.
struct ArmTube: Shape {
    let curve: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let x = rect.midX
        path.move(to: CGPoint(x: x, y: rect.minY))
        guard curve != 0 else {
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            return path
        }
        path.addCurve(
            to: CGPoint(x: x, y: rect.maxY),
            control1: CGPoint(x: x - curve, y: rect.minY + rect.height * 0.28),
            control2: CGPoint(x: x + curve, y: rect.minY + rect.height * 0.72)
        )
        return path
    }
}

/// Tonearm drawn as a vertical assembly so the parent can rotate it about the pivot.
///
/// Layout from top to bottom: counterweight, pivot, tube, headshell. `pivotAnchor`
/// reports where the pivot sits inside the view's own bounds, which the parent feeds
/// straight into `rotationEffect(anchor:)`.
struct TonearmView: View {
    let tubeLength: CGFloat

    /// cos of the lift angle. Shortens the tube and counterweight — the parts that run
    /// along the arm's axis — while the pivot keeps its diameter. Scaling the whole view
    /// instead would squash the pivot into an ellipse, and the pivot is the rotation
    /// centre: it stays put and stays round however far the arm is raised.
    var foreshortening: CGFloat = 1

    @Environment(\.theme) private var theme

    static let counterweightHeight: CGFloat = 10
    static let pivotDiameter: CGFloat = 10
    static let headshellHeight: CGFloat = 9

    /// Fixed distance between the pivot centre and the stylus, excluding the tube.
    static let hardwareLength = pivotDiameter / 2 + headshellHeight / 2

    private var counterweightHeight: CGFloat { Self.counterweightHeight * foreshortening }
    private var pivotDiameter: CGFloat { Self.pivotDiameter }
    private var headshellHeight: CGFloat { Self.headshellHeight }
    private var projectedTube: CGFloat { tubeLength * foreshortening }

    private var curve: CGFloat {
        if case .pivoted(let curve) = theme.armStyle { return curve }
        return 0
    }

    /// Wide enough to hold the bend and the anti-skate outrigger. Deliberately independent
    /// of `foreshortening`: tilting the arm out of the platter plane shortens it along its
    /// own axis only, so the sideways swell keeps its width.
    private var width: CGFloat {
        var needed = max(13, theme.counterweightWidth + 1)
        needed = max(needed, 2 * curve + theme.armTubeWidth + 6)
        if theme.hasAntiSkate { needed = max(needed, 26) }
        return needed
    }

    var totalHeight: CGFloat {
        counterweightHeight + pivotDiameter + projectedTube + headshellHeight
    }

    var pivotAnchor: UnitPoint {
        UnitPoint(x: 0.5, y: (counterweightHeight + pivotDiameter / 2) / totalHeight)
    }

    /// Distance from the pivot to the stylus, which is what the tracking geometry needs.
    var stylusDistance: CGFloat {
        Self.hardwareLength + tubeLength
    }

    private var metal: LinearGradient {
        LinearGradient(
            colors: theme.armMetal,
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var pivotCenterY: CGFloat { counterweightHeight + pivotDiameter / 2 }

    var body: some View {
        let centerX = width / 2
        let tubeTop = counterweightHeight + pivotDiameter
        return ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: theme.counterweight,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: theme.counterweightWidth, height: counterweightHeight)
                .position(x: centerX, y: counterweightHeight / 2)

            ArmTube(curve: curve)
                .stroke(metal, style: StrokeStyle(lineWidth: theme.armTubeWidth,
                                                  lineCap: .round))
                .frame(width: width, height: projectedTube)
                .position(x: centerX, y: tubeTop + projectedTube / 2)

            if theme.hasAntiSkate {
                antiSkate(centerX: centerX)
            }

            Circle()
                .fill(metal)
                .frame(width: pivotDiameter, height: pivotDiameter)
                .overlay(
                    // Darkened rather than filled flat, so the hub picks up whatever
                    // metal the skin runs underneath it.
                    Circle()
                        .fill(Color.black.opacity(0.72))
                        .frame(width: pivotDiameter * 0.34, height: pivotDiameter * 0.34)
                )
                .shadow(color: .black.opacity(0.5 * theme.shadowStrength), radius: 2, y: 1)
                .position(x: centerX, y: pivotCenterY)

            // Headshell tilts slightly, the way a real cartridge mount is offset.
            RoundedRectangle(cornerRadius: 2.5)
                .fill(
                    LinearGradient(
                        colors: theme.headshell,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 8, height: headshellHeight)
                .rotationEffect(.degrees(11))
                .position(x: centerX, y: totalHeight - headshellHeight / 2)
        }
        .frame(width: width, height: totalHeight)
    }

    /// Outrigger weight on a short arm beside the bearing, hung off to the side the way
    /// the anti-skate thread is on a deck that has one.
    private func antiSkate(centerX: CGFloat) -> some View {
        let reach: CGFloat = 9
        return ZStack {
            Capsule()
                .fill(metal)
                .frame(width: reach, height: 1.6)
                .position(x: centerX + pivotDiameter / 2 + reach / 2, y: pivotCenterY)

            Circle()
                .fill(
                    LinearGradient(
                        colors: theme.counterweight,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 5, height: 5)
                .position(x: centerX + pivotDiameter / 2 + reach, y: pivotCenterY + 1)
        }
    }
}

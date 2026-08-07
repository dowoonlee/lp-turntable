import SwiftUI

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

    static let counterweightHeight: CGFloat = 10
    static let pivotDiameter: CGFloat = 10
    static let headshellHeight: CGFloat = 9

    /// Fixed distance between the pivot centre and the stylus, excluding the tube.
    static let hardwareLength = pivotDiameter / 2 + headshellHeight / 2

    private var counterweightHeight: CGFloat { Self.counterweightHeight * foreshortening }
    private var pivotDiameter: CGFloat { Self.pivotDiameter }
    private var headshellHeight: CGFloat { Self.headshellHeight }
    private var projectedTube: CGFloat { tubeLength * foreshortening }

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
            colors: [Color(white: 0.88), Color(white: 0.55), Color(white: 0.78)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.30), Color(white: 0.14)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 12, height: counterweightHeight)

            Circle()
                .fill(metal)
                .frame(width: pivotDiameter, height: pivotDiameter)
                .overlay(
                    Circle()
                        .fill(Color(white: 0.22))
                        .frame(width: pivotDiameter * 0.34, height: pivotDiameter * 0.34)
                )
                .shadow(color: .black.opacity(0.5), radius: 2, y: 1)

            Capsule()
                .fill(metal)
                .frame(width: 3, height: projectedTube)

            // Headshell tilts slightly, the way a real cartridge mount is offset.
            RoundedRectangle(cornerRadius: 2.5)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.82), Color(white: 0.48)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 8, height: headshellHeight)
                .rotationEffect(.degrees(11))
        }
        .frame(width: 13, height: totalHeight)
    }
}

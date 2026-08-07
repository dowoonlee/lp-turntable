import SwiftUI

/// Hardware bolted to the plinth beside the platter.
///
/// Everything is placed in panel coordinates, so the parent hands this view the panel's own
/// frame and lets it position its own controls. They all sit to the *left* of the platter,
/// which is the one concession to the panel size: a real SL-1200 puts its pitch fader at
/// the bottom right, and here that is where the tonearm parks.
struct DeckControls: View {
    @Environment(\.theme) private var theme

    @ViewBuilder
    var body: some View {
        switch theme.deckHardware {
        case .none:
            EmptyView()
        case .djConsole:
            djConsole
        case .rotaryKnob:
            rotaryKnob
        case .glowStrip:
            glowStrip
        }
    }

    private var housing: LinearGradient {
        LinearGradient(colors: theme.armRestPost,
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }

    private var djConsole: some View {
        ZStack {
            // Pitch fader: a recessed slot with the knob parked a touch above centre,
            // the way a deck sits when nobody has touched the pitch.
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(Color.black.opacity(0.22))
                .frame(width: 7, height: 48)
                .position(x: 16, y: 96)

            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(housing)
                .frame(width: 13, height: 6)
                .position(x: 16, y: 90)

            // Strobe lamp. Red on every deck that has one.
            Circle()
                .fill(theme.controlAccent)
                .frame(width: 4, height: 4)
                .position(x: 16, y: 64)

            // Start/stop, with the lamp that says the platter is powered.
            Circle()
                .fill(housing)
                .frame(width: 15, height: 15)
                .overlay(
                    Circle()
                        .fill(theme.controlAccent.opacity(0.85))
                        .frame(width: 5, height: 5)
                )
                .position(x: 17, y: 148)
        }
        .shadow(color: .black.opacity(0.4 * theme.shadowStrength), radius: 2, y: 1)
    }

    private var rotaryKnob: some View {
        Circle()
            .fill(housing)
            .frame(width: 17, height: 17)
            .overlay(
                Capsule()
                    .fill(theme.controlAccent)
                    .frame(width: 2, height: 6)
                    .offset(y: -4)
            )
            .shadow(color: .black.opacity(0.4 * theme.shadowStrength), radius: 2, y: 1)
            .position(x: 18, y: 149)
    }

    /// Lit strip below the track info, fading out at both ends so it reads as spill from
    /// under the deck rather than a drawn line.
    private var glowStrip: some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        theme.controlAccent.opacity(0),
                        theme.controlAccent.opacity(0.85),
                        theme.controlAccent.opacity(0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 132, height: 2.5)
            .blur(radius: 0.7)
            .position(x: 100, y: 212)
    }
}

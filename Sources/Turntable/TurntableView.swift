import SwiftUI

struct TurntableView: View {
    @ObservedObject var monitor: NowPlayingMonitor

    /// Taken as a parameter and injected into the environment below, rather than read from
    /// the environment here. That keeps the root view's type as plain `TurntableView`, so
    /// swapping skins is an assignment to `NSHostingView.rootView`.
    var theme: Theme = .walnut

    /// Current tilt of the arm out of the platter plane, in degrees.
    @State private var armTilt: Double = 0

    // Fixed geometry: the panel is a fixed size, so the deck can be laid out in
    // absolute coordinates instead of threading a GeometryReader through.
    static let panelSize = CGSize(width: 200, height: 224)

    private let platterCenter = CGPoint(x: 100, y: 86)
    private let pivot = CGPoint(x: 175, y: 58)

    /// Set by the skin. Safe to vary because nothing downstream stores a radius: the arm
    /// derives its length from the pivot and solves its angle from whatever record is
    /// actually on the platter.
    private var platterDiameter: CGFloat { theme.platterDiameter }

    /// Where the stylus starts and finishes, in panel points.
    private var outerRadius: CGFloat { platterDiameter * 0.47 }
    private var innerRadius: CGFloat { platterDiameter * theme.innermostGrooveRatio }

    /// Radius the stylus should be sitting at right now.
    private var trackingRadius: CGFloat {
        outerRadius + (innerRadius - outerRadius) * monitor.progress
    }

    /// Gap between the outermost groove and where a linear tracker parks.
    private static let railParkGap: CGFloat = 13

    private var pivotToSpindle: CGFloat {
        let dx = platterCenter.x - pivot.x
        let dy = platterCenter.y - pivot.y
        return sqrt(dx * dx + dy * dy)
    }

    /// Arm length is matched to the pivot→spindle distance. A longer arm can never
    /// reach the centre — it bottoms out at `|distance - length|` from the spindle —
    /// so matching the two is what lets the stylus travel all the way in.
    private var tubeLength: CGFloat {
        pivotToSpindle - TonearmView.hardwareLength
    }

    /// Where the arm parks when nothing is playing: straight down from the pivot, which
    /// puts the stylus clear of the record on its rest.
    ///
    /// A vertical lift is the physically faithful answer, but from directly overhead it
    /// is nearly invisible — a real deck only tells you by the cue lever or by the arm
    /// sitting on its rest. Parking the arm is what actually reads as "stopped".
    private static let restAngle: Double = -6

    /// How far the arm tilts out of the platter plane while in transit.
    ///
    /// What is animated is this angle, not the resulting length. Seen from above the arm
    /// foreshortens by cos θ, and cos is flat near 0° and steep near 30°, so driving the
    /// angle gives a length that eases in and out on its own — fastest mid-travel. Easing
    /// the length directly would instead lurch at the start and crawl at the end.
    private static let liftAngle: Double = 30

    private static let liftUpDuration = 0.16
    private static let liftDownDuration = 0.28
    private static let swingDuration = 0.65

    /// nil means "as fast as the display refreshes".
    private static let frameInterval: Double? = {
        guard let raw = ProcessInfo.processInfo.environment["TURNTABLE_FPS"],
              let fps = Double(raw), fps > 0 else { return nil }
        return 1.0 / fps
    }()

    var body: some View {
        ZStack {
            deck

            DeckControls()
                .frame(width: Self.panelSize.width, height: Self.panelSize.height)

            VinylPlatter(diameter: platterDiameter)
                .position(platterCenter)

            // Only the disc redraws at animation rate. A nil minimumInterval lets the
            // schedule run at the display's full refresh rate; TURNTABLE_FPS caps it
            // for anyone who would rather trade smoothness back for CPU.
            TimelineView(.animation(minimumInterval: Self.frameInterval,
                                    paused: !monitor.track.isPlaying)) { _ in
                VinylDisc(
                    artwork: monitor.artwork,
                    // 33⅓ RPM is 200°/s; the skin decides, and a 45 is half again as fast.
                    rotation: monitor.spinSeconds * theme.degreesPerSecond,
                    diameter: platterDiameter
                )
                .position(platterCenter)
            }

            VinylChrome(diameter: platterDiameter)
                .position(platterCenter)

            if !theme.isLinearTracked {
                armRest
            }

            // The arm sweeps a few degrees per minute, so once a second is plenty.
            TimelineView(.periodic(from: .now, by: 1.0)) { _ in
                if theme.isLinearTracked {
                    linearArm
                } else {
                    tonearm
                }
            }

            trackInfo
                .padding(.horizontal, 16)
                .frame(width: Self.panelSize.width, alignment: .leading)
                .position(x: Self.panelSize.width / 2, y: 188)
        }
        .environment(\.theme, theme)
        .frame(width: Self.panelSize.width, height: Self.panelSize.height)
        .background(deckBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(theme.deckBorder, lineWidth: 1)
        )
        .onChange(of: monitor.track.isPlaying) { _ in
            liftSwingAndSetDown()
        }
    }

    /// Lift → swing → set down. Cueing hardware snaps up but lowers on a damper, so the
    /// descent is the slower of the two.
    private func liftSwingAndSetDown() {
        withAnimation(.easeOut(duration: Self.liftUpDuration)) {
            armTilt = Self.liftAngle
        }
        let descentStart = Self.swingDuration - Self.liftDownDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + descentStart) {
            withAnimation(.easeInOut(duration: Self.liftDownDuration)) {
                armTilt = 0
            }
        }
    }

    // MARK: - Deck

    private var deckBackground: some View {
        LinearGradient(
            colors: theme.deckGradient,
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var deck: some View {
        // Faint plinth ring so the platter reads as recessed into the deck. Kept outside
        // the mat whatever width the skin gives it.
        let diameter = platterDiameter * (theme.platterRingRatio + 0.08)
        return Circle()
            .strokeBorder(theme.plinthRing, lineWidth: 1)
            .frame(width: diameter, height: diameter)
            .position(platterCenter)
    }

    /// A rail lies along the record's radius, so playback position is a distance instead of
    /// an angle — there is no triangle to solve and no arc for the stylus to ride.
    private var linearArm: some View {
        let parkRadius = outerRadius + Self.railParkGap
        let radius = monitor.track.isPlaying ? trackingRadius : parkRadius
        let span = parkRadius - innerRadius
        let travel = span > 0 ? Double((parkRadius - radius) / span) : 0

        let length = span + LinearArmView.carriageWidth
        // Carry the rail past the spindle so it reads as a bridge over the record rather
        // than a bar that stops in the middle of it.
        let overhang = innerRadius + 7
        let width = length + overhang
        let left = platterCenter.x + innerRadius - LinearArmView.carriageWidth / 2 - overhang

        let radians = armTilt * .pi / 180
        let lift = Double(sin(radians) / sin(Self.liftAngle * .pi / 180))

        return LinearArmView(length: length, carriage: travel, lift: lift,
                             railOverhang: overhang)
            .position(x: left + width / 2,
                      y: platterCenter.y - LinearArmView.stylusOffset)
            .animation(.easeInOut(duration: Self.swingDuration),
                       value: monitor.track.isPlaying)
    }

    private var tonearm: some View {
        let radians = armTilt * .pi / 180
        // Height above the platter drives the shadow; length is its cosine counterpart.
        let elevation = sin(radians) / sin(Self.liftAngle * .pi / 180)

        let arm = TonearmView(tubeLength: tubeLength, foreshortening: cos(radians))
        let pivotOffset = arm.pivotAnchor.y * arm.totalHeight
        return arm
            .rotationEffect(.degrees(armAngle), anchor: arm.pivotAnchor)
            // Applied after the rotation so the light stays fixed — inside the arm the
            // shadow would swing around with it.
            .shadow(color: .black.opacity((0.45 - 0.15 * elevation) * theme.shadowStrength),
                    radius: 3 + 5 * elevation,
                    x: 2 + 4 * elevation,
                    y: 3 + 6 * elevation)
            .position(x: pivot.x, y: pivot.y + arm.totalHeight / 2 - pivotOffset)
            .animation(.easeInOut(duration: Self.swingDuration), value: monitor.track.isPlaying)
    }

    /// Cradle the arm parks on. Sits just past the stylus at `restAngle`.
    private var armRest: some View {
        let stylus = stylusPoint(at: Self.restAngle)
        return ZStack {
            // Post, wider than the headshell so it still reads once the arm is parked.
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: theme.armRestPost,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 13, height: 17)
            // Cradle the tube settles into.
            Capsule()
                .fill(theme.armRestCradle)
                .frame(width: 10, height: 4)
                .offset(y: -6)
        }
        .shadow(color: .black.opacity(0.5 * theme.shadowStrength), radius: 3, y: 2)
        .position(x: stylus.x, y: stylus.y + 5)
    }

    /// Stylus position for a given arm angle, in panel coordinates.
    private func stylusPoint(at angle: Double) -> CGPoint {
        let distance = TonearmView(tubeLength: tubeLength).stylusDistance
        let radians = angle * .pi / 180
        return CGPoint(
            x: pivot.x - distance * sin(radians),
            y: pivot.y + distance * cos(radians)
        )
    }

    /// Angle that puts the stylus at the radius matching current playback progress —
    /// the arm sweeping inward is what shows how far into the track we are.
    ///
    /// Solves the pivot–spindle–stylus triangle with the law of cosines, so the arm
    /// tracks the way it would on a real deck rather than by a linear guess.
    private var armAngle: Double {
        guard monitor.track.isPlaying else { return Self.restAngle }

        let stylusDistance = TonearmView(tubeLength: tubeLength).stylusDistance
        let radius = trackingRadius

        let dx = platterCenter.x - pivot.x
        let dy = platterCenter.y - pivot.y
        let pivotToSpindle = sqrt(dx * dx + dy * dy)

        let cosTheta = (pivotToSpindle * pivotToSpindle
                        + stylusDistance * stylusDistance
                        - radius * radius)
            / (2 * pivotToSpindle * stylusDistance)
        let theta = acos(min(1, max(-1, cosTheta)))

        // Angle of the pivot→spindle line. `rotationEffect` turns the arm's straight-down
        // axis into (-sin, cos), so the horizontal term is negated relative to the usual
        // atan2(x, y) form — getting this backwards swings the arm off the record entirely.
        let base = atan2(-dx, dy)

        // theta opens away from the spindle, so a larger radius means a smaller angle.
        return (base - theta) * 180 / .pi
    }

    // MARK: - Track info

    @ViewBuilder
    private var trackInfo: some View {
        switch monitor.state {
        case .cliMissing:
            VStack(alignment: .leading, spacing: 3) {
                Text("nowplaying-cli 가 필요합니다")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.noticeColor)
                Text("brew install nowplaying-cli")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(theme.mutedColor)
            }

        case .idle:
            Text("재생 중인 음악이 없습니다")
                .font(.system(size: 11))
                .foregroundStyle(theme.mutedColor)

        case .playing:
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    if !monitor.track.isPlaying {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(theme.mutedColor)
                    }
                    Text(monitor.track.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.titleColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Text(monitor.track.artist)
                    .font(.system(size: 10))
                    .foregroundStyle(theme.subtitleColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }
}

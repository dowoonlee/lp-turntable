import AppKit
import Combine

struct Track: Equatable {
    var title: String
    var artist: String
    var album: String
    var duration: Double
    var isPlaying: Bool

    static let empty = Track(title: "", artist: "", album: "", duration: 0, isPlaying: false)

    var isEmpty: Bool { title.isEmpty }
}

enum MonitorState: Equatable {
    case playing
    case idle
    case cliMissing
}

/// Kept at file scope so the background reader can touch them without actor hops.
private let infoPrefix = "kMRMediaRemoteNowPlayingInfo"
private let cliSearchPaths = [
    "/opt/homebrew/bin/nowplaying-cli",
    "/usr/local/bin/nowplaying-cli"
]

/// Polls `nowplaying-cli get-raw` and exposes a continuously advancing playback position.
///
/// MediaRemote only refreshes the elapsed time roughly once a minute for the YouTube Music
/// PWA and omits the timestamp key that would let us interpolate directly. So we latch the
/// moment the reported value changes and extrapolate from that instant, which keeps the
/// needle smooth between refreshes.
@MainActor
final class NowPlayingMonitor: ObservableObject {
    @Published private(set) var track = Track.empty
    @Published private(set) var artwork: NSImage?
    @Published private(set) var state = MonitorState.idle

    private var timer: Timer?
    private var lastReportedElapsed: Double = -1
    private var lastArtworkFingerprint = 0
    private var positionBase: Double = 0
    private var positionAnchor = Date()

    /// Playback position in seconds, advancing in real time between MediaRemote refreshes.
    var position: Double {
        guard track.isPlaying else { return positionBase }
        let extrapolated = positionBase + Date().timeIntervalSince(positionAnchor)
        guard track.duration > 0 else { return extrapolated }
        return min(extrapolated, track.duration)
    }

    /// Seconds of playback driving the platter rotation.
    ///
    /// Deliberately separate from `position`: every time MediaRemote republishes the
    /// elapsed time we re-anchor, and that correction is routinely a second or two —
    /// which at 200°/s would show up as the record visibly skipping. The rotation phase
    /// carries no information, so it just needs to advance monotonically while playing.
    var spinSeconds: Double {
        guard let spinResumedAt else { return spinAccumulated }
        return spinAccumulated + Date().timeIntervalSince(spinResumedAt)
    }

    private var spinAccumulated: Double = 0
    private var spinResumedAt: Date?

    var progress: Double {
        // TURNTABLE_PROGRESS pins the arm at a fixed position so the tracking geometry
        // can be checked without waiting out a whole song.
        if let progressOverride {
            return progressOverride
        }
        guard track.duration > 0 else { return 0 }
        return min(1, max(0, position / track.duration))
    }

    /// true = force paused, false = force playing, nil = follow MediaRemote.
    private let pausedOverride: Bool? = {
        guard let raw = ProcessInfo.processInfo.environment["TURNTABLE_PAUSED"] else { return nil }
        return !(raw == "0" || raw.lowercased() == "false")
    }()

    private let progressOverride: Double? = {
        guard let raw = ProcessInfo.processInfo.environment["TURNTABLE_PROGRESS"],
              let value = Double(raw) else { return nil }
        return min(1, max(0, value))
    }()

    func start() {
        refresh()
        // 0.5s keeps track changes (and their artwork) visibly prompt; one CLI call
        // costs ~1.5ms, so the extra polling is not what drives CPU here.
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        guard let cli = Self.cliPath else {
            state = .cliMissing
            return
        }

        Task.detached(priority: .utility) {
            let info = Self.readInfo(cli: cli)
            await MainActor.run { self.apply(info) }
        }
    }

    private func apply(_ info: [String: Any]?) {
        guard let info, let title = info["Title"] as? String, !title.isEmpty else {
            track = .empty
            artwork = nil
            state = .idle
            lastReportedElapsed = -1
            lastArtworkFingerprint = 0
            setSpinning(false)
            return
        }

        let elapsed = info["ElapsedTime"] as? Double ?? 0
        let wasPlaying = track.isPlaying
        let changedTrack = title != track.title
        let extrapolatedBefore = position

        var next = Track.empty
        next.title = title
        next.artist = info["Artist"] as? String ?? ""
        next.album = info["Album"] as? String ?? ""
        next.duration = info["Duration"] as? Double ?? 0
        // TURNTABLE_PAUSED pins the transport state so the cueing lift can be checked
        // in both directions without touching whatever is actually playing.
        if let pausedOverride {
            next.isPlaying = !pausedOverride
        } else {
            next.isPlaying = (info["PlaybackRate"] as? Double ?? 0) > 0
        }

        if changedTrack {
            lastReportedElapsed = -1
        }
        let reanchored = elapsed != lastReportedElapsed

        // Re-anchor whenever MediaRemote publishes a fresh position, and also on any
        // play/pause edge so the extrapolation never runs while the platter is still.
        if elapsed != lastReportedElapsed {
            positionBase = elapsed
            positionAnchor = Date()
            lastReportedElapsed = elapsed
        } else if wasPlaying != next.isPlaying {
            positionBase = position
            positionAnchor = Date()
        }

        track = next
        state = .playing
        setSpinning(next.isPlaying)
        updateArtwork(info: info)

        if traceEnabled {
            // `reanchor` is the correction the platter used to inherit: tying rotation
            // to the playback position moved it by that many seconds × 200°.
            let correction = elapsed - extrapolatedBefore
            let reanchorText = reanchored && !changedTrack
                ? String(format: "%+.2fs = %.0f deg", correction, abs(correction) * 200)
                : "-"
            trace(String(format: "raw=%7.2f  spin=%8.2f  reanchor=%@%@",
                         elapsed, spinSeconds, reanchorText,
                         changedTrack ? "  TRACK-CHANGED" : ""))
        }
    }

    private let traceEnabled = ProcessInfo.processInfo.environment["TURNTABLE_TRACE"] != nil
    private let launchedAt = Date()

    private func trace(_ message: String) {
        guard traceEnabled else { return }
        let line = String(format: "t=%7.2f  %@\n", Date().timeIntervalSince(launchedAt), message)
        FileHandle.standardError.write(Data(line.utf8))
    }

    /// Starts or freezes the rotation clock, banking elapsed spin time on the way down.
    private func setSpinning(_ spinning: Bool) {
        if spinning {
            if spinResumedAt == nil { spinResumedAt = Date() }
        } else if let started = spinResumedAt {
            spinAccumulated += Date().timeIntervalSince(started)
            spinResumedAt = nil
        }
    }

    /// Keyed on the artwork payload itself, not the track title.
    ///
    /// MediaRemote often publishes the new title a beat before the new artwork, so
    /// keying on the title would latch whatever image happened to be attached at that
    /// moment — usually the previous track's — and never pick up the real one.
    private func updateArtwork(info: [String: Any]) {
        let encoded = info["ArtworkData"] as? String
        let fingerprint = encoded?.hashValue ?? 0
        guard fingerprint != lastArtworkFingerprint else { return }
        lastArtworkFingerprint = fingerprint

        guard let encoded,
              let data = Data(base64Encoded: encoded),
              let image = NSImage(data: data) else {
            artwork = nil
            trace("ARTWORK cleared")
            return
        }
        artwork = image
        trace(String(format: "ARTWORK updated (%d bytes)", data.count))
    }

    private nonisolated static var cliPath: String? {
        cliSearchPaths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private nonisolated static func readInfo(cli: String) -> [String: Any]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cli)
        process.arguments = ["get-raw"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Strip the kMRMediaRemoteNowPlayingInfo prefix so call sites read cleanly.
        return raw.reduce(into: [String: Any]()) { result, entry in
            guard entry.key.hasPrefix(infoPrefix) else { return }
            result[String(entry.key.dropFirst(infoPrefix.count))] = entry.value
        }
    }
}

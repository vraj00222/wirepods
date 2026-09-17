import Foundation
import UIKit
import AVFoundation
import Combine

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published var title: String = "Demo — Apple HLS (Bip Bop)"
    @Published var subtitle: String = "Plays here, routes to Mac via AirPlay"
    @Published var isPlaying: Bool = false
    @Published var progress: Double = 0
    @Published var customURLString: String = ""

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    init() {
        loadDemoHLS()
        // Observe background/foreground for handoff
        NotificationCenter.default.addObserver(forName: .wirePodsBackgrounded, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.handleBackgrounded() }
        }
        NotificationCenter.default.addObserver(forName: .wirePodsForegrounded, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.handleForegrounded() }
        }
    }

    func loadDemoHLS() {
        let url = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8")!
        load(url: url, title: "Bip Bop (Apple Demo HLS)")
    }

    func loadCustomURL() {
        guard let url = URL(string: customURLString.trimmingCharacters(in: .whitespacesAndNewlines)),
              UIApplication.shared.canOpenURL(url) || customURLString.hasPrefix("http") else { return }
        // Allow http(s) only
        guard let parsed = URL(string: customURLString), parsed.scheme?.hasPrefix("http") == true else { return }
        load(url: parsed, title: parsed.lastPathComponent)
    }

    private func load(url: URL, title: String) {
        self.title = title
        subtitle = url.host ?? url.absoluteString
        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 0.5 // low latency: was  default ~5s
        // Don't wait to minimize stalling
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = false
        if player == nil {
            player = AVPlayer(playerItem: item)
            player?.allowsExternalPlayback = true
            player?.usesExternalPlaybackWhileExternalScreenIsActive = false
            player?.automaticallyWaitsToMinimizeStalling = false
            addTimeObserver()
        } else {
            player?.replaceCurrentItem(with: item)
            player?.automaticallyWaitsToMinimizeStalling = false
        }
        // Pre-warm audio session low latency
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        try? AVAudioSession.sharedInstance().setPreferredIOBufferDuration(0.02)
    }

    func togglePlayPause(focusController: IOSFocusController) {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
            focusController.releaseFocus()
        } else {
            player.play()
            isPlaying = true
            // Claim focus when playback starts — triggers AirPlay routing if Mac is selected
            focusController.claimFocus()
        }
    }

    func skipBack() {
        guard let p = player else { return }
        let t = p.currentTime().seconds - 10
        p.seek(to: CMTime(seconds: max(0, t), preferredTimescale: 600))
    }

    func skipForward() {
        guard let p = player else { return }
        let t = p.currentTime().seconds + 10
        p.seek(to: CMTime(seconds: t, preferredTimescale: 600))
    }

    private func addTimeObserver() {
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self, let item = self.player?.currentItem else { return }
                let duration = item.duration.seconds
                if duration.isFinite && duration > 0 {
                    self.progress = time.seconds / duration
                }
                if time.seconds >= duration - 0.3 && duration.isFinite {
                    self.isPlaying = false
                }
            }
        }
    }

    private func handleBackgrounded() {
        // Don't auto-pause; just release focus so Mac can take over
        // If you want auto-pause, uncomment:
        // player?.pause(); isPlaying = false
    }

    private func handleForegrounded() {
        // If we were playing, reclaim focus
        if isPlaying {
            // Will be done by toggle logic; nothing needed
        }
    }

    deinit {
        if let t = timeObserver { player?.removeTimeObserver(t) }
        if let o = endObserver { NotificationCenter.default.removeObserver(o) }
    }
}

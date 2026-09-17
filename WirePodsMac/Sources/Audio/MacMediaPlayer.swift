import Foundation
import AVFoundation

/// Plays handed-off URL directly on Mac (wired buds) for ms-level handoff.
/// Instead of AirPlay (500ms-1s buffer), iPhone sends mediaURL and Mac plays it itself.
/// Only for WirePods content (HLS/MP3 URLs). Much faster than AirPlay streaming.

final class MacMediaPlayer: NSObject {
    private var player: AVPlayer?
    private var item: AVPlayerItem?

    var isPlaying: Bool { player?.rate != 0 }

    func play(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 0.3
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = false
        if player == nil {
            let p = AVPlayer(playerItem: item)
            p.automaticallyWaitsToMinimizeStalling = false
            p.play()
            player = p
        } else {
            player?.replaceCurrentItem(with: item)
            player?.automaticallyWaitsToMinimizeStalling = false
            player?.play()
        }
        self.item = item
        print("[MacMediaPlayer] playing \(urlString) → wired buds")
    }

    func pause() {
        player?.pause()
    }

    func stop() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
    }
}

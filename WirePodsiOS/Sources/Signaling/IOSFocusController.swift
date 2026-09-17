import Foundation
import Combine
import Network
import WirePodsCore

@available(iOS 17, *)
@MainActor
final class IOSFocusController: ObservableObject {
    @Published private(set) var peerConnected: Bool = false
    @Published private(set) var focus: AudioFocus = .idle
    @Published private(set) var lastEvent: String = "Idle"

    private var audioController: AudioFocusController?
    private var macAudioReceiver: MacAudioReceiver?

    func start() {
        let name = UIDevice.current.name
        let controller = AudioFocusController(device: .iphone, deviceName: name)
        controller.onShouldDuck = { [weak self] in
            print("[WirePods iOS] Mac claimed focus — ducking")
            NotificationCenter.default.post(name: .wirePodsShouldDuck, object: nil)
        }
        controller.onShouldResume = {
            print("[WirePods iOS] Mac released — can resume")
            NotificationCenter.default.post(name: .wirePodsShouldResume, object: nil)
        }
        // Bridge published values
        controller.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.peerConnected = controller.peerConnected
                self?.focus = controller.focus
                self?.lastEvent = controller.lastEvent
            }
        }.store(in: &cancellables)
        controller.start()
        audioController = controller

        // Poll bridge every 0.5s (since AudioFocusController publishes on its own queue)
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let c = self?.audioController else { return }
                self?.peerConnected = c.peerConnected
                self?.focus = c.focus
                self?.lastEvent = c.lastEvent
            }
        }
    }

    func stop() {
        audioController?.stop()
        macAudioReceiver?.stop()
    }

    func claimFocus() {
        audioController?.claimFocus(reason: "iphone-playback-start")
    }

    func releaseFocus() {
        audioController?.releaseFocus()
    }

    // MARK: - Mac → iPhone audio stream (vice-versa)

    func startMacAudioStream() {
        macAudioReceiver = MacAudioReceiver()
        macAudioReceiver?.start()
    }

    func stopMacAudioStream() {
        macAudioReceiver?.stop()
        macAudioReceiver = nil
    }

    private var cancellables = Set<AnyCancellable>()
}

extension Notification.Name {
    static let wirePodsShouldDuck = Notification.Name("wirePodsShouldDuck")
    static let wirePodsShouldResume = Notification.Name("wirePodsShouldResume")
}

// MARK: - MacAudioReceiver (receives PCM from WirePodsMac)

import AVFoundation

final class MacAudioReceiver: NSObject {
    private var connection: NWConnection?
    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "wirepods.macAudioReceiver")
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?

    func start() {
        let params = NWParameters.tcp
        params.includePeerToPeer = true
        let descriptor = NWBrowser.Descriptor.bonjour(type: "_wirepods-audio._tcp", domain: "local.")
        browser = NWBrowser(for: descriptor, using: params)
        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            guard let result = results.first else { return }
            let conn = NWConnection(to: result.endpoint, using: params)
            self?.setupConnection(conn)
        }
        browser?.start(queue: queue)
        setupAudioEngine()
        print("[MacAudioReceiver] browsing for _wirepods-audio._tcp")
    }

    func stop() {
        browser?.cancel()
        connection?.cancel()
        audioEngine?.stop()
    }

    private func setupAudioEngine() {
        let engine = AVAudioEngine()
        let node = AVAudioPlayerNode()
        engine.attach(node)
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        engine.connect(node, to: engine.mainMixerNode, format: format)
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? engine.start()
        node.play()
        audioEngine = engine
        playerNode = node
    }

    private func setupConnection(_ conn: NWConnection) {
        connection = conn
        conn.stateUpdateHandler = { state in
            if case .ready = state {
                print("[MacAudioReceiver] connected to Mac streamer")
                self.receive()
            }
        }
        conn.start(queue: queue)
    }

    private func receive() {
        connection?.receive(minimumIncompleteLength: 4, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self, let data, !data.isEmpty else {
                if let error { print("[MacAudioReceiver] error: \(error)") }
                return
            }
            self.handlePacket(data)
            if !isComplete { self.receive() }
        }
    }

    private func handlePacket(_ data: Data) {
        // Simple framing: 4-byte big-endian length + PCM bytes
        guard data.count >= 4 else { return }
        let len = data.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        let pcm = data.dropFirst(4).prefix(Int(len))
        guard pcm.count == len else { return }
        // Schedule on playerNode as PCM buffer
        // For brevity assume 16-bit interleaved stereo at 48kHz
        // Production would use proper AudioStreamPacketDescription / Opus decode
        pcm.withUnsafeBytes { raw in
            // Create PCM buffer and schedule
            let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48000, channels: 2, interleaved: true)!
            let frameCount = UInt32(pcm.count) / format.streamDescription.pointee.mBytesPerFrame
            guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
            buf.frameLength = frameCount
            if let dst = buf.int16ChannelData?[0] {
                memcpy(dst, raw.baseAddress!, pcm.count)
            }
            self.playerNode?.scheduleBuffer(buf, completionHandler: nil)
        }
    }
}

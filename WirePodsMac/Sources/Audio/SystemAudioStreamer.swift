import Foundation
import ScreenCaptureKit
import Network

/// Streams Mac system audio to iPhone app via NWListener on a random port.
/// Uses ScreenCaptureKit (macOS 13+) to capture system audio — requires Screen Recording permission.
/// Audio is streamed as raw PCM frames wrapped in a tiny header; iPhone side decodes.
/// This powers the "vice-versa: Mac YouTube -> phone" direction.

@available(macOS 14, *)
final class SystemAudioStreamer: NSObject, Sendable, SCStreamOutput, SCStreamDelegate {

    private var stream: SCStream?
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let queue = DispatchQueue(label: "wirepods.streamer")

    var isStreaming: Bool { stream != nil }

    func start(port: UInt16 = 0) {
        Task { await startCapture() }
        startListener(port: port)
    }

    func stop() {
        Task { try? await stream?.stopCapture() }
        stream = nil
        listener?.cancel()
        connections.forEach { $0.cancel() }
        connections.removeAll()
    }

    // MARK: ScreenCaptureKit

    private func startCapture() async {
        do {
            let content = try await SCShareableContent.current
            guard let display = content.displays.first else {
                print("[Streamer] No display found")
                return
            }
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.capturesAudio = true
            config.excludesCurrentProcessAudio = true
            config.sampleRate = 48000
            config.channelCount = 2
            // We only need audio; set tiny video size to minimize overhead
            config.width = 2
            config.height = 2
            config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

            let s = SCStream(filter: filter, configuration: config, delegate: self)
            try s.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
            try await s.startCapture()
            stream = s
            print("[Streamer] SCStream started (system audio)")
        } catch {
            print("[Streamer] Failed to start capture: \(error) — need Screen Recording permission.")
        }
    }

    // MARK: SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        // Forward raw audio bytes to all connected iPhone peers
        // For brevity: extract AudioBufferList and send as Data
        // Production would encode Opus/AAC; here we send PCM chunk with header.
        guard let block = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        let length = CMBlockBufferGetDataLength(block)
        var data = Data(count: length)
        data.withUnsafeMutableBytes { ptr in
            CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: ptr.baseAddress!)
        }
        // Prefix with 4-byte length header for framing
        var header = withUnsafeBytes(of: UInt32(length).bigEndian) { Data($0) }
        header.append(data)
        let packet = header
        for conn in connections where conn.state == .ready {
            conn.send(content: packet, completion: .contentProcessed { _ in })
        }
    }

    // MARK: NWListener for iPhone to connect

    private func startListener(port: UInt16) {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        do {
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port) ?? .any)
        } catch {
            print("[Streamer] listener failed: \(error)")
            return
        }
        listener?.service = NWListener.Service(name: "WirePods-Audio", type: "_wirepods-audio._tcp")
        listener?.newConnectionHandler = { [weak self] conn in
            self?.handleNewAudioConnection(conn)
        }
        listener?.start(queue: queue)
        print("[Streamer] audio listener started")
    }

    private func handleNewAudioConnection(_ conn: NWConnection) {
        connections.append(conn)
        conn.stateUpdateHandler = { [weak self] state in
            if case .failed = state { self?.connections.removeAll { $0 === conn } }
            if case .cancelled = state { self?.connections.removeAll { $0 === conn } }
        }
        conn.start(queue: queue)
        print("[Streamer] iPhone audio client connected")
    }
}

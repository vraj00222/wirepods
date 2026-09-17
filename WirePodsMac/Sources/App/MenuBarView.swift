import SwiftUI

struct MenuBarView: View {
    weak var delegate: AppDelegate?

    @State private var airPlayEnabled: Bool = false
    @State private var peerConnected: Bool = false
    @State private var focus: AudioFocus = .idle
    @State private var lastEvent: String = "Idle"
    @State private var wiredOutputName: String = "Unknown"

    private let checker = AirPlayReceiverChecker()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "headphones.circle.fill")
                    .font(.title2).foregroundStyle(.blue)
                VStack(alignment: .leading) {
                    Text("WirePods").font(.headline)
                    Text("Wired buds stay on Mac").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Circle().fill(peerConnected ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                Text(peerConnected ? "Peer linked" : "No peer")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            Divider()

            // AirPlay Receiver status
            HStack {
                Image(systemName: airPlayEnabled ? "airplayaudio" : "exclamationmark.triangle")
                    .foregroundStyle(airPlayEnabled ? .green : .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(airPlayEnabled ? "AirPlay Receiver: Enabled" : "AirPlay Receiver: Disabled")
                        .font(.subheadline.weight(.medium))
                    Text(airPlayEnabled ? "iPhone can route here via AirPlay" : "Turn on in System Settings → AirDrop & Continuity")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if !airPlayEnabled {
                    Button("Open Settings") { checker.openSettings() }
                        .buttonStyle(.bordered).controlSize(.small)
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))

            // Focus state
            VStack(alignment: .leading, spacing: 6) {
                Label("Audio Focus: \(focus.rawValue)", systemImage: focusIcon)
                    .font(.subheadline.weight(.semibold))
                Text(lastEvent).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }

            // Wired output
            HStack {
                Image(systemName: "cable.connector")
                Text("Wired output: \(wiredOutputName)").font(.caption)
                Spacer()
                Button("Refresh") { Task { await refreshAudio() } }
                    .controlSize(.small)
            }

            Divider()

            HStack(spacing: 8) {
                Button(action: { delegate?.claimMacFocus() }) {
                    Label("Active: Mac", systemImage: "macbook")
                }.buttonStyle(.borderedProminent).controlSize(.small)

                Button(action: { delegate?.releaseFocus() }) {
                    Label("Release", systemImage: "pause.circle")
                }.buttonStyle(.bordered).controlSize(.small)

                Spacer()

                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain).font(.caption)
            }

            Text("Tip: YouTube on Mac → claim 'Active: Mac'. Reels on iPhone claims automatically when WirePods iOS plays.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 360)
        .task {
            await refreshAudio()
            airPlayEnabled = await checker.isEnabled()
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            if let d = delegate?.focusController {
                peerConnected = d.peerConnected
                focus = d.focus
                lastEvent = d.lastEvent
            }
            Task { airPlayEnabled = await checker.isEnabled() }
        }
    }

    private var focusIcon: String {
        switch focus {
        case .idle: return "circle.dashed"
        case .macActive: return "macbook"
        case .iphoneActive: return "iphone"
        case .transitioning: return "arrow.triangle.swap"
        }
    }

    private func refreshAudio() async {
        wiredOutputName = SystemAudioDevice.currentOutputName() ?? "Unknown"
    }
}

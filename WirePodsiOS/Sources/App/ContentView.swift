import SwiftUI
import AVKit

struct ContentView: View {
    @StateObject private var playerVM = PlayerViewModel()
    @StateObject private var focusController = IOSFocusController()
    @State private var listenToMac = false

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Connection banner
                HStack {
                    Circle().fill(focusController.peerConnected ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)
                    Text(focusController.peerConnected ? "Mac linked — auto handoff active" : "Searching for Mac on Wi-Fi…")
                        .font(.caption.weight(.medium))
                    Spacer()
                    Text(focusController.focus.rawValue)
                        .font(.caption2).padding(4).background(Capsule().fill(Color.secondary.opacity(0.15)))
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))

                // AirPlay route picker (system UI) — user must tap once; then auto-reconnects
                VStack(alignment: .leading, spacing: 8) {
                    Label("AirPlay to Mac (one-time tap, then automatic)", systemImage: "airplayaudio")
                        .font(.caption.weight(.semibold))
                    AirPlayPickerView()
                        .frame(height: 44)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.tertiarySystemFill)))
                    Text("Pick your Mac's AirPlay target. Wired buds are on the Mac — audio will play there.")
                        .font(.caption2).foregroundStyle(.secondary)
                }

                // Player card
                PlayerCard(playerVM: playerVM, focusController: focusController)

                // Handoff controls
                HStack(spacing: 10) {
                    Button(action: { focusController.claimFocus() }) {
                        Label("Claim (Reels start)", systemImage: "iphone.gen3")
                    }.buttonStyle(.borderedProminent).controlSize(.small)

                    Button(action: { focusController.releaseFocus() }) {
                        Label("Release", systemImage: "pause.circle")
                    }.buttonStyle(.bordered).controlSize(.small)

                    Spacer()
                }

                Divider()

                Toggle(isOn: $listenToMac) {
                    Label("Listen to Mac audio on this phone", systemImage: "macbook.and.iphone")
                }
                .onChange(of: listenToMac) { _, on in
                    if on { focusController.startMacAudioStream() }
                    else { focusController.stopMacAudioStream() }
                }
                Text("Streams Mac system audio (YouTube etc.) to this phone over Wi-Fi via WirePodsMac. Needs Screen Recording permission on Mac.")
                    .font(.caption2).foregroundStyle(.secondary)

                Spacer()

                // Help footer
                VStack(spacing: 4) {
                    Text("How it works").font(.caption.weight(.semibold))
                    Text("Play inside this app → auto AirPlays to Mac's wired buds. Leave this app / pause → Mac regains focus. For Instagram Reels outside this app, use Control Center → Screen Mirroring → Mac (Path A).")
                        .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
            }
            .padding()
            .navigationTitle("WirePods")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { focusController.start() }
        .onDisappear { focusController.stop() }
    }
}

struct PlayerCard: View {
    @ObservedObject var playerVM: PlayerViewModel
    @ObservedObject var focusController: IOSFocusController

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "play.circle.fill").font(.title).foregroundStyle(.blue)
                VStack(alignment: .leading) {
                    Text(playerVM.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text(playerVM.subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if playerVM.isPlaying {
                    Image(systemName: "waveform").foregroundStyle(.blue).symbolEffect(.variableColor)
                }
            }

            // Progress
            Slider(value: $playerVM.progress, in: 0...1)
                .tint(.blue)

            HStack(spacing: 12) {
                Button(action: { playerVM.skipBack() }) {
                    Image(systemName: "gobackward.10")
                }
                Button(action: { playerVM.togglePlayPause(focusController: focusController) }) {
                    Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(Color.blue))
                        .foregroundStyle(.white)
                }
                Button(action: { playerVM.skipForward() }) {
                    Image(systemName: "goforward.10")
                }
                Spacer()
                Menu {
                    Button("Demo stream (Apple HLS)") { playerVM.loadDemoHLS() }
                    Button("Load from URL…") { playerVM.loadDemoHLS() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }

            // URL field for custom content (since Reels can't be proxied)
            TextField("Paste HLS / MP3 URL to play", text: $playerVM.customURLString)
                .textFieldStyle(.roundedBorder).font(.caption)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            Button("Load & Play") { playerVM.loadCustomURL() }
                .buttonStyle(.bordered).controlSize(.small)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
    }
}

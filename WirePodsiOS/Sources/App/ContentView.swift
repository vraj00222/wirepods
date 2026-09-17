import SwiftUI
import AVKit

struct ContentView: View {
    @StateObject private var playerVM = PlayerViewModel()
    @StateObject private var focusController = IOSFocusController()
    @State private var listenToMac = false
    @State private var showPairing = !PairingStore.hasCompletedOnboarding

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Connection banner — now shows trusted state
                HStack {
                    Circle().fill(focusController.peerConnected ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)
                    if focusController.peerConnected {
                        Text(PairingStore.hasCompletedOnboarding ? "Mac trusted — hands-free" : "Mac linked — tap Done to go hands-free")
                            .font(.caption.weight(.medium))
                    } else {
                        Text("Searching for Mac on same Wi-Fi…")
                            .font(.caption.weight(.medium))
                    }
                    Spacer()
                    Text(focusController.focus.rawValue)
                        .font(.caption2).padding(4).background(Capsule().fill(Color.secondary.opacity(0.15)))
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))

                // Pairing card — one-time only, then never again
                if !PairingStore.hasCompletedOnboarding {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("One-time pairing (same Wi-Fi, keeps it safe)", systemImage: "lock.shield")
                            .font(.caption.weight(.semibold))
                        Text("1. Make sure your M4 MacBook and iPhone 17 are on the same Wi-Fi.\n2. Open WirePodsMac on the Mac (menu bar 🎧).\n3. Tap the AirPlay button below and pick your Mac once. iOS remembers it forever.")
                            .font(.caption2).foregroundStyle(.secondary)
                        AirPlayPickerView()
                            .frame(height: 44)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(.tertiarySystemFill)))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.4), lineWidth: 1))
                        Button("Done — go hands-free") {
                            PairingStore.hasCompletedOnboarding = true
                            if let name = focusController.lastEvent { PairingStore.trustedPeerName = name }
                            showPairing = false
                        }
                        .buttonStyle(.borderedProminent).controlSize(.small)
                        .disabled(!focusController.peerConnected)
                        Text(focusController.peerConnected ? "Mac found ✓" : "Waiting for WirePodsMac… make sure both are on same Wi-Fi and WirePodsMac is running.")
                            .font(.caption2).foregroundStyle(focusController.peerConnected ? .green : .secondary)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.15), lineWidth: 1))
                } else {
                    // Compact AirPlay indicator after pairing — no tap needed, but visible
                    HStack {
                        Image(systemName: "airplayaudio").foregroundStyle(.blue)
                        Text("AirPlay to \(PairingStore.trustedPeerName ?? "Mac") — paired")
                            .font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        AirPlayPickerView().frame(width: 30, height: 30).opacity(0.5)
                    }
                }

                // Player card — auto-claims on play, so no manual Claim needed after pairing
                PlayerCard(playerVM: playerVM, focusController: focusController)

                // Optional advanced — collapsed after pairing
                DisclosureGroup("Advanced") {
                    HStack(spacing: 10) {
                        Button(action: { focusController.claimFocus() }) {
                            Label("Force claim", systemImage: "iphone.gen3")
                        }.buttonStyle(.bordered).controlSize(.small)
                        Button(action: { focusController.releaseFocus() }) {
                            Label("Release", systemImage: "pause.circle")
                        }.buttonStyle(.bordered).controlSize(.small)
                        Button("Forget pairing") {
                            PairingStore.clear()
                            showPairing = true
                        }.buttonStyle(.plain).font(.caption).foregroundStyle(.red)
                    }
                    Toggle(isOn: $listenToMac) {
                        Label("Listen to Mac audio on this phone (optional)", systemImage: "macbook.and.iphone")
                    }
                    .onChange(of: listenToMac) { _, on in
                        if on { focusController.startMacAudioStream() }
                        else { focusController.stopMacAudioStream() }
                    }
                    Text("Optional: streams Mac audio to phone over Wi-Fi. Off by default for your use-case — you look at the iPhone screen, so only iPhone → Mac is needed. No Screen Recording prompt unless you turn this on.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .font(.caption)

                Spacer()

                VStack(spacing: 4) {
                    Text("Zero-touch after this").font(.caption.weight(.semibold))
                    Text("After this one-time AirPlay pick on same Wi-Fi, just press play here or play YouTube on the Mac — sound stays in the wired buds on the Mac, no taps. Same Wi-Fi keeps it safe; no cloud, no extra hardware.")
                        .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
            }
            .padding()
            .navigationTitle("WirePods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if PairingStore.hasCompletedOnboarding {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Re-pair") { PairingStore.clear(); showPairing = true }
                            .font(.caption)
                    }
                }
            }
        }
        .onAppear { focusController.start() }
        .onDisappear { focusController.stop() }
        .sheet(isPresented: $showPairing) {
            if !PairingStore.hasCompletedOnboarding {
                // Full-screen pairing if not yet done
            }
        }
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
            Slider(value: $playerVM.progress, in: 0...1).tint(.blue)
            HStack(spacing: 12) {
                Button(action: { playerVM.skipBack() }) { Image(systemName: "gobackward.10") }
                Button(action: { playerVM.togglePlayPause(focusController: focusController) }) {
                    Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3).frame(width: 48, height: 48)
                        .background(Circle().fill(Color.blue)).foregroundStyle(.white)
                }
                Button(action: { playerVM.skipForward() }) { Image(systemName: "goforward.10") }
                Spacer()
                Menu {
                    Button("Demo stream (Apple HLS)") { playerVM.loadDemoHLS() }
                } label: { Image(systemName: "ellipsis.circle") }
            }
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

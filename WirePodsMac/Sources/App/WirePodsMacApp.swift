import SwiftUI
import WirePodsCore

@main
struct WirePodsMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover = NSPopover()
    var focusController: AudioFocusController!
    var airPlayChecker = AirPlayReceiverChecker()
    var systemAudioStreamer: SystemAudioStreamer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupFocusController()
        setupSystemAudioStreamer()

        // Check AirPlayReceiver
        Task {
            let enabled = await airPlayChecker.isEnabled()
            print("[WirePodsMac] AirPlay Receiver enabled: \(enabled)")
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "headphones", accessibilityDescription: "WirePods")
            button.action = #selector(togglePopover)
            button.target = self
        }
        popover.contentSize = NSSize(width: 360, height: 420)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuBarView(
            delegate: self
        ))
    }

    private func setupFocusController() {
        focusController = AudioFocusController(device: .mac)
        focusController.onShouldDuck = { [weak self] in
            print("[WirePodsMac] Ducking — pausing browser media")
            BrowserMediaController.pauseAll()
        }
        focusController.onShouldResume = {
            print("[WirePodsMac] Peer released — can resume")
        }
        focusController.start()
    }

    private func setupSystemAudioStreamer() {
        systemAudioStreamer = SystemAudioStreamer()
    }

    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown { popover.performClose(nil) }
            else { popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
        }
    }

    func claimMacFocus() {
        focusController.claimFocus(reason: "mac-active")
    }

    func releaseFocus() {
        focusController.releaseFocus()
    }
}

// MARK: - SettingsView

struct SettingsView: View {
    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: .constant(false))
                    .disabled(true)
                Text("Enable in System Settings → General → Login Items")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 400, height: 200)
    }
}

import SwiftUI
import AVKit
import AVFoundation

/// Wraps AVRoutePickerView so SwiftUI can show the system AirPlay picker.
/// The user must tap this once to select the Mac; iOS then remembers the choice
/// and will auto-reconnect on next playback if the Mac is available.

struct AirPlayPickerView: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.activeTintColor = UIColor.systemBlue
        view.tintColor = UIColor.systemGray
        // Prioritize AirPlay / route picker for external playback
        if #available(iOS 17.0, *) {
            // No extra config needed; AVAudioSession .allowAirPlay already set
        }
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}

    // Optionally expose programmatic hint (requires user gesture to actually present)
    static func presentRoutePicker() {
        // Note: no public API to programmatically show picker without user tap.
        // Some apps use private API MPAVRoutingController — rejected by App Store.
        // We intentionally do not use private API.
    }
}

/// Volume view variant that also works as route picker on older iOS
struct AirPlayButton: View {
    @State private var showHint = false
    var body: some View {
        HStack {
            AirPlayPickerView().frame(width: 44, height: 44)
            if showHint {
                Text("Tap to pick your Mac").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 1) { showHint = true } }
    }
}

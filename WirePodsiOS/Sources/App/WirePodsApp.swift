import SwiftUI
import AVFoundation

@main
struct WirePodsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear { configureAudioSession() }
        }
    }

    private func configureAudioSession() {
        do {
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.playback, mode: .default, options: [])
            try s.setPreferredIOBufferDuration(0.02) // low latency: 20ms
            try s.setActive(true)
        } catch {
            print("[WirePods] AVAudioSession failed: \(error)")
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Notify Mac that iPhone is backgrounded -> can release focus
        NotificationCenter.default.post(name: .wirePodsBackgrounded, object: nil)
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        NotificationCenter.default.post(name: .wirePodsForegrounded, object: nil)
    }
}

extension Notification.Name {
    static let wirePodsBackgrounded = Notification.Name("wirePodsBackgrounded")
    static let wirePodsForegrounded = Notification.Name("wirePodsForegrounded")
}

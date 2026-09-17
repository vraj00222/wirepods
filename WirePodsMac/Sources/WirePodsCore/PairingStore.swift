import Foundation

/// Persists trusted peer after first successful pairing on same Wi-Fi.
/// After this, handoff is zero-touch: no AirPlay picker tap (iOS remembers route) and no Screen Mirroring tap.

public final class PairingStore: Sendable {
    private static let keyTrustedPeer = "wirepods.trustedPeer"
    private static let keyPairedAt = "wirepods.pairedAt"
    private static let keyHasCompletedOnboarding = "wirepods.hasCompletedOnboarding"

    public static var trustedPeerName: String? {
        get { UserDefaults.standard.string(forKey: keyTrustedPeer) }
        set { UserDefaults.standard.set(newValue, forKey: keyTrustedPeer) }
    }

    public static var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: keyHasCompletedOnboarding) }
        set { UserDefaults.standard.set(newValue, forKey: keyHasCompletedOnboarding) }
    }

    public static func trust(peer name: String) {
        trustedPeerName = name
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: keyPairedAt)
        hasCompletedOnboarding = true
    }

    public static func clear() {
        UserDefaults.standard.removeObject(forKey: keyTrustedPeer)
        UserDefaults.standard.removeObject(forKey: keyPairedAt)
        hasCompletedOnboarding = false
    }
}

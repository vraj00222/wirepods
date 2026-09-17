import Foundation
import Combine

/// Coordinates local playback state with remote peer via BonjourTransport.
/// Platform-agnostic; UI layers observe `focus` and `peerConnected`.
@available(macOS 14, iOS 17, *)
public final class AudioFocusController: ObservableObject {

    @Published public private(set) var focus: AudioFocus = .idle
    @Published public private(set) var peerConnected: Bool = false
    @Published public private(set) var lastEvent: String = "Idle"

    private let device: HandoffDevice
    private let deviceName: String
    private let stateMachine = HandoffStateMachine()
    private var transport: BonjourTransport?
    private var heartbeatTimer: Timer?

    public var onShouldDuck: (() -> Void)?
    public var onShouldResume: (() -> Void)?

    public init(device: HandoffDevice, deviceName: String? = nil) {
        self.device = device
        self.deviceName = deviceName ?? (ProcessInfo.processInfo.hostName)

        stateMachine.onFocusChange = { [weak self] focus, msg in
            guard let self else { return }
            DispatchQueue.main.async {
                self.focus = focus
                if let msg {
                    self.lastEvent = "\(msg.device.rawValue) \(msg.action.rawValue) — \(msg.deviceName)"
                    self.handleSideEffect(focus: focus, message: msg)
                }
            }
        }
    }

    // MARK: Lifecycle

    public func start() {
        transport = BonjourTransport(role: .both, deviceName: deviceName)
        transport?.onMessage = { [weak self] msg, _ in
            _ = self?.stateMachine.handle(msg)
        }
        transport?.onPeerConnected = { [weak self] _ in
            DispatchQueue.main.async { self?.peerConnected = true }
            // Exchange capabilities on connect
            let cap = HandoffMessage.Capabilities(
                hasWiredOutput: true,
                airPlayReceiverEnabled: true,
                canCaptureSystemAudio: true,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            )
            let msg = HandoffMessage(action: .capability, device: self?.device ?? .unknown, deviceName: self?.deviceName ?? "Unknown", capabilities: cap)
            self?.transport?.broadcast(msg)
        }
        transport?.onPeerDisconnected = { [weak self] _ in
            DispatchQueue.main.async { self?.peerConnected = false }
        }
        transport?.start()
        startHeartbeat()
    }

    public func stop() {
        heartbeatTimer?.invalidate()
        transport?.stop()
        transport = nil
    }

    // MARK: Public actions

    public func claimFocus(reason: String? = nil) {
        var msg = stateMachine.localClaim(device: device, name: deviceName)
        msg.reason = reason
        _ = stateMachine.handle(msg)
        transport?.broadcast(msg)
        lastEvent = "Claimed (\(reason ?? "user"))"
    }

    public func releaseFocus() {
        let msg = stateMachine.localRelease(device: device, name: deviceName)
        _ = stateMachine.handle(msg)
        transport?.broadcast(msg)
        lastEvent = "Released"
    }

    public func sendHeartbeat() {
        let msg = HandoffMessage(action: .heartbeat, device: device, deviceName: deviceName)
        transport?.broadcast(msg)
    }

    // MARK: Private

    private func handleSideEffect(focus: AudioFocus, message: HandoffMessage) {
        // If peer claimed focus and we currently hold it, we should duck
        switch focus {
        case .iphoneActive where device == .mac:
            // iPhone took focus — Mac should duck/pause YouTube
            onShouldDuck?()
        case .macActive where device == .iphone:
            onShouldDuck?()
        case .idle:
            onShouldResume?()
        default:
            break
        }
    }

    private func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
    }
}

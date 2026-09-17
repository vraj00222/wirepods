import Foundation
import Network

// MARK: - BonjourTransport
// Lightweight NWListener + NWConnection over Bonjour _wirepods._tcp.
// Both sides can be browser and advertiser. First peer to connect becomes client.

@available(macOS 14, iOS 17, *)
public final class BonjourTransport: NSObject, Sendable {

    public enum Role { case advertiser, browser, both }

    private let role: Role
    private let deviceName: String
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connections: [NWConnection] = []
    private let queue = DispatchQueue(label: "wirepods.bonjour", qos: .userInitiated)
    private var receiveBuffers: [ObjectIdentifier: Data] = [:]

    public var onMessage: ((HandoffMessage, NWConnection) -> Void)?
    public var onPeerConnected: ((String) -> Void)?
    public var onPeerDisconnected: ((String) -> Void)?

    public init(role: Role = .both, deviceName: String = Host.current().localizedName ?? "WirePods") {
        self.role = role
        self.deviceName = deviceName
        super.init()
    }

    // MARK: Start / Stop

    public func start() {
        if role == .advertiser || role == .both { startAdvertising() }
        if role == .browser || role == .both { startBrowsing() }
    }

    public func stop() {
        listener?.cancel()
        browser?.cancel()
        connections.forEach { $0.cancel() }
        connections.removeAll()
    }

    // MARK: Advertising

    private func startAdvertising() {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        params.includePeerToPeer = true

        do {
            listener = try NWListener(using: params)
        } catch {
            print("[WirePods] NWListener failed: \(error)")
            return
        }

        listener?.service = NWListener.Service(name: deviceName, type: WirePodsService.type)
        listener?.newConnectionHandler = { [weak self] conn in
            self?.setupConnection(conn, isIncoming: true)
        }
        listener?.stateUpdateHandler = { state in
            if case .failed(let err) = state {
                print("[WirePods] listener failed: \(err)")
            }
        }
        listener?.start(queue: queue)
        print("[WirePods] advertising as \(deviceName) \(WirePodsService.type)")
    }

    // MARK: Browsing

    private func startBrowsing() {
        let params = NWParameters.tcp
        params.includePeerToPeer = true
        let descriptor = NWBrowser.Descriptor.bonjour(type: WirePodsService.type, domain: WirePodsService.domain)
        browser = NWBrowser(for: descriptor, using: params)
        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            for result in results {
                if case .service(let name, _, _, _) = result.endpoint, name == self?.deviceName {
                    continue // ignore self
                }
                // Connect to first discovered peer if not already connected
                if self?.connections.isEmpty == true {
                    let conn = NWConnection(to: result.endpoint, using: params)
                    self?.setupConnection(conn, isIncoming: false)
                }
            }
        }
        browser?.stateUpdateHandler = { state in
            if case .failed(let err) = state {
                print("[WirePods] browser failed: \(err)")
            }
        }
        browser?.start(queue: queue)
        print("[WirePods] browsing \(WirePodsService.type)")
    }

    // MARK: Connection handling

    private func setupConnection(_ conn: NWConnection, isIncoming: Bool) {
        connections.append(conn)
        conn.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.onPeerConnected?(conn.endpoint.debugDescription)
                self?.receive(on: conn)
            case .failed(let err):
                print("[WirePods] connection failed: \(err)")
                self?.remove(conn)
            case .cancelled:
                self?.remove(conn)
            default: break
            }
        }
        conn.start(queue: queue)
    }

    private func remove(_ conn: NWConnection) {
        queue.async { [weak self] in
            self?.connections.removeAll { $0 === conn }
            self?.receiveBuffers.removeValue(forKey: ObjectIdentifier(conn))
            self?.onPeerDisconnected?(conn.endpoint.debugDescription)
        }
    }

    private func receive(on conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.handleReceived(data, from: conn)
            }
            if let error {
                print("[WirePods] receive error: \(error)")
                return
            }
            if isComplete {
                self.remove(conn)
            } else {
                self.receive(on: conn)
            }
        }
    }

    private func handleReceived(_ data: Data, from conn: NWConnection) {
        let id = ObjectIdentifier(conn)
        var buffer = receiveBuffers[id] ?? Data()
        buffer.append(data)
        let (messages, remainder) = HandoffMessage.decodeLines(from: buffer)
        receiveBuffers[id] = remainder
        for msg in messages {
            DispatchQueue.main.async { [weak self] in
                self?.onMessage?(msg, conn)
            }
        }
    }

    // MARK: Send

    public func broadcast(_ msg: HandoffMessage) {
        guard let data = try? msg.encoded() else { return }
        for conn in connections where conn.state == .ready {
            conn.send(content: data, completion: .contentProcessed { err in
                if let err { print("[WirePods] send error: \(err)") }
            })
        }
    }

    public var isConnected: Bool {
        connections.contains { $0.state == .ready }
    }
}

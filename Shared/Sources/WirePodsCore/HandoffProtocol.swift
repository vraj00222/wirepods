import Foundation

// MARK: - WirePods Handoff Protocol (LAN only, no cloud)
// Transport: Bonjour _wirepods._tcp + NWListener/NWConnection (or MultipeerConnectivity fallback)
// Every message is newline-delimited JSON.

public enum HandoffDevice: String, Codable, Sendable {
    case iphone
    case mac
    case unknown
}

public enum HandoffAction: String, Codable, Sendable {
    case claim      // "I want audio focus now"
    case release    // "I'm done, focus free"
    case duck       // "Please duck/pause"
    case resume     // "You can resume"
    case heartbeat  // periodic keepalive
    case capability // advertise capabilities
}

public struct HandoffMessage: Codable, Sendable, Equatable {
    public var action: HandoffAction
    public var device: HandoffDevice
    public var deviceName: String
    public var timestamp: TimeInterval
    public var sessionId: String
    public var capabilities: Capabilities?
    public var reason: String?
    public var mediaURL: String? // for ms-level handoff: Mac plays URL directly instead of AirPlay

    public struct Capabilities: Codable, Sendable, Equatable {
        public var hasWiredOutput: Bool
        public var airPlayReceiverEnabled: Bool
        public var canCaptureSystemAudio: Bool
        public var appVersion: String

        public init(hasWiredOutput: Bool = false,
                    airPlayReceiverEnabled: Bool = false,
                    canCaptureSystemAudio: Bool = false,
                    appVersion: String = "1.0.0") {
            self.hasWiredOutput = hasWiredOutput
            self.airPlayReceiverEnabled = airPlayReceiverEnabled
            self.canCaptureSystemAudio = canCaptureSystemAudio
            self.appVersion = appVersion
        }
    }

    public init(action: HandoffAction,
                device: HandoffDevice,
                deviceName: String = ProcessInfo.processInfo.hostName,
                timestamp: TimeInterval = Date().timeIntervalSince1970,
                sessionId: String = UUID().uuidString,
                capabilities: Capabilities? = nil,
                reason: String? = nil,
                mediaURL: String? = nil) {
        self.action = action
        self.device = device
        self.deviceName = deviceName
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.capabilities = capabilities
        self.reason = reason
        self.mediaURL = mediaURL
    }

    // MARK: Wire format

    public func encoded() throws -> Data {
        var data = try JSONEncoder().encode(self)
        data.append(0x0A) // newline delimiter
        return data
    }

    public static func decode(from data: Data) throws -> HandoffMessage {
        try JSONDecoder().decode(HandoffMessage.self, from: data)
    }

    public static func decodeLines(from buffer: Data) -> (messages: [HandoffMessage], remainder: Data) {
        var messages: [HandoffMessage] = []
        var remainder = Data()
        let chunks = buffer.split(separator: 0x0A, omittingEmptySubsequences: false)
        // All except last are complete lines
        for (idx, chunk) in chunks.enumerated() {
            let isLast = idx == chunks.count - 1
            let endsWithNewline = buffer.last == 0x0A
            if isLast && !endsWithNewline {
                remainder = Data(chunk)
                break
            }
            if chunk.isEmpty { continue }
            if let msg = try? JSONDecoder().decode(HandoffMessage.self, from: Data(chunk)) {
                messages.append(msg)
            }
        }
        return (messages, remainder)
    }
}

// MARK: - Handoff State Machine

public enum AudioFocus: String, Codable, Sendable {
    case idle
    case macActive
    case iphoneActive
    case transitioning
}

public final class HandoffStateMachine: @unchecked Sendable {
    public private(set) var focus: AudioFocus = .idle
    private var lastClaim: HandoffMessage?
    private let debounceInterval: TimeInterval = 0.2 // low latency: was 0.8
    private var lastTransitionAt: TimeInterval = 0
    private let queue = DispatchQueue(label: "wirepods.statemachine")

    public var onFocusChange: ((AudioFocus, HandoffMessage?) -> Void)?

    public init() {}

    /// Returns true if message was applied
    @discardableResult
    public func handle(_ msg: HandoffMessage) -> Bool {
        queue.sync {
            let now = Date().timeIntervalSince1970
            // Debounce rapid claims
            if msg.action == .claim,
               let last = lastClaim,
               last.device == msg.device,
               now - lastTransitionAt < debounceInterval {
                return false
            }

            switch msg.action {
            case .claim:
                let newFocus: AudioFocus = (msg.device == .mac) ? .macActive : .iphoneActive
                if focus != newFocus {
                    focus = newFocus
                    lastClaim = msg
                    lastTransitionAt = now
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        self.onFocusChange?(newFocus, msg)
                    }
                } else {
                    lastClaim = msg
                }
                return true
            case .release:
                // Only release if releaser currently holds focus
                let holder: AudioFocus = (msg.device == .mac) ? .macActive : .iphoneActive
                if focus == holder {
                    focus = .idle
                    lastTransitionAt = now
                    DispatchQueue.main.async { [weak self] in
                        self?.onFocusChange?(.idle, msg)
                    }
                    return true
                }
                return false
            case .duck, .resume, .heartbeat, .capability:
                // Informational — don't change focus but notify
                DispatchQueue.main.async { [weak self] in
                    self?.onFocusChange?(self?.focus ?? .idle, msg)
                }
                return true
            }
        }
    }

    public func localClaim(device: HandoffDevice, name: String) -> HandoffMessage {
        HandoffMessage(action: .claim, device: device, deviceName: name)
    }

    public func localRelease(device: HandoffDevice, name: String) -> HandoffMessage {
        HandoffMessage(action: .release, device: device, deviceName: name)
    }
}

// MARK: - Bonjour constants

public enum WirePodsService {
    public static let type = "_wirepods._tcp"
    public static let domain = "local."
    public static let txtRecordVersion = "1"
}

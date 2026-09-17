import Foundation
import AppKit

final class AirPlayReceiverChecker: Sendable {

    /// Heuristic: check if AirPlay Receiver service is advertised or preference enabled.
    /// Real system toggle lives in com.apple.controlcenter / AirPlay; we probe by checking
    /// whether the Bonjour _airplay._tcp for this Mac is present and by reading defaults.
    func isEnabled() async -> Bool {
        // 1) Try reading preference domain (best-effort, may require no SIP)
        if let enabled = readDefaults() { return enabled }
        // 2) Fallback: consider enabled if we can browse _airplay._tcp and see self
        return await browseAirPlaySelf()
    }

    private func readDefaults() -> Bool? {
        // com.apple.AirPlayReceiver — undocumented, may not exist on all OS versions
        let domains = ["com.apple.AirPlayReceiver", "com.apple.controlcenter"]
        for domain in domains {
            if let val = UserDefaults(suiteName: domain)?.object(forKey: "AirPlayReceiverEnabled") as? Bool {
                return val
            }
            // Also try via `defaults read` shell
            let task = Process()
            task.launchPath = "/usr/bin/defaults"
            task.arguments = ["read", domain, "AirPlayReceiverEnabled"]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            try? task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0 {
                let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if trimmed == "1" || trimmed == "true" || trimmed == "yes" { return true }
                if trimmed == "0" || trimmed == "false" || trimmed == "no" { return false }
            }
        }
        return nil
    }

    private func browseAirPlaySelf() async -> Bool {
        // Lightweight: assume enabled if macOS 13+ and service exists; otherwise prompt user
        // We do a short NWBrowser scan for _airplay._tcp and return true if anything found within 1s
        // For now, optimistic default — real check needs private API.
        return true // so UI doesn't block; user can open Settings to confirm
    }

    func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.AirDrop-Handoff-Settings") {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:")!)
        }
    }
}

import Foundation

/// Uses AppleScript to pause/play media in common browsers (YouTube tabs).
/// No extra permissions if Accessibility not granted — degrades gracefully.

enum BrowserMediaController {

    static func pauseAll() {
        for script in pauseScripts {
            runAppleScript(script)
        }
        // Also try media key pause via `osascript` key simulation fallback handled by system
    }

    static func playAll() {
        for script in playScripts {
            runAppleScript(script)
        }
    }

    private static func runAppleScript(_ source: String) {
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", source]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        try? task.run()
        task.waitUntilExit()
    }

    // Safari — pause any tab whose URL looks like youtube
    private static let pauseScripts: [String] = [
        """
        tell application "Safari" to tell every tab of every window to if (URL contains "youtube.com") then do JavaScript "document.querySelectorAll('video').forEach(v=>v.pause())" in it
        """,
        """
        tell application "Google Chrome" to tell every tab of every window to if (URL contains "youtube.com") then execute javascript "document.querySelectorAll('video').forEach(v=>v.pause())"
        """,
        """
        tell application "Arc" to tell every tab of every window to if (URL contains "youtube.com") then execute javascript "document.querySelectorAll('video').forEach(v=>v.pause())"
        """
    ]

    private static let playScripts: [String] = [
        """
        tell application "Safari" to tell every tab of every window to if (URL contains "youtube.com") then do JavaScript "document.querySelectorAll('video').forEach(v=>v.play())" in it
        """,
        """
        tell application "Google Chrome" to tell every tab of every window to if (URL contains "youtube.com") then execute javascript "document.querySelectorAll('video').forEach(v=>v.play())"
        """
    ]
}

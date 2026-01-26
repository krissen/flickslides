import AppKit
import CoreGraphics
import Foundation
import FlickSlidesKit

/// Simulerar tangentbordstryck via CGEvent.
final class KeyboardSimulator {
    private var lastCommandTime: Date = .distantPast
    private let debounceInterval: TimeInterval

    /// App-specifika tangentmappningar
    /// Key: bundle identifier, Value: [command: keyCode]
    private let appSpecificKeys: [String: [PresentationCommand: UInt16]] = [
        // Skim använder pil upp/ned för navigering
        "net.sourceforge.skim-app.skim": [
            .next: 125,      // ↓ (Down arrow)
            .previous: 126   // ↑ (Up arrow)
        ]
    ]

    init(debounceInterval: TimeInterval = FlickSlidesConstants.macCommandCooldown) {
        self.debounceInterval = debounceInterval
    }

    /// Aktivera en app baserat på bundle identifier.
    /// - Parameter bundleId: Bundle identifier för appen (t.ex. "com.apple.iWork.Keynote")
    /// - Returns: `true` om appen aktiverades, `false` annars.
    @discardableResult
    func activateApp(bundleId: String) async -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        guard let app = runningApps.first(where: { $0.bundleIdentifier == bundleId }) else {
            print("[KeyboardSimulator] App not found: \(bundleId)")
            return false
        }

        // Använd activate(options:) för att tvinga aktivering från bakgrund
        let success = app.activate(options: [.activateIgnoringOtherApps])
        if success {
            print("[KeyboardSimulator] Activated app: \(app.localizedName ?? bundleId)")
            // Ge appen tid att komma till förgrunden (non-blocking)
            try? await Task.sleep(nanoseconds: 150_000_000)  // 150ms
        } else {
            print("[KeyboardSimulator] Failed to activate app: \(bundleId)")
        }
        return success
    }

    /// Skicka en tangent.
    /// - Returns: `true` om tangenten skickades, `false` om debounce blockerade.
    @discardableResult
    func sendKey(_ keyCode: CGKeyCode) -> Bool {
        let now = Date()
        guard now.timeIntervalSince(lastCommandTime) > debounceInterval else {
            print("[KeyboardSimulator] Debounce blocked key: \(keyCode)")
            return false
        }
        lastCommandTime = now

        let source = CGEventSource(stateID: .combinedSessionState)

        guard let keyDown = CGEvent(keyboardEventSource: source,
                                     virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source,
                                   virtualKey: keyCode, keyDown: false) else {
            print("[KeyboardSimulator] Failed to create key events")
            return false
        }

        keyDown.post(tap: .cgSessionEventTap)
        keyUp.post(tap: .cgSessionEventTap)

        print("[KeyboardSimulator] Sent key: \(keyCode)")
        return true
    }

    /// Hantera ett PresentationCommand.
    /// - Parameters:
    ///   - command: Kommandot att utföra
    ///   - targetAppBundleId: Optional bundle ID för målappen. Om angiven aktiveras appen först.
    /// - Returns: `true` om kommandot utfördes.
    func handleCommand(_ command: PresentationCommand, targetAppBundleId: String? = nil) async -> Bool {
        // Om målapp är angiven, aktivera den först
        if let bundleId = targetAppBundleId {
            if await !activateApp(bundleId: bundleId) {
                print("[KeyboardSimulator] Could not activate target app, sending key anyway")
            }
        }

        // Hämta app-specifik tangent eller använd standard
        let keyCode: UInt16
        if let bundleId = targetAppBundleId,
           let appKeys = appSpecificKeys[bundleId],
           let specificKey = appKeys[command] {
            keyCode = specificKey
            print("[KeyboardSimulator] Using app-specific key for \(bundleId): \(keyCode)")
        } else {
            keyCode = command.keyCode
        }

        return sendKey(CGKeyCode(keyCode))
    }
}

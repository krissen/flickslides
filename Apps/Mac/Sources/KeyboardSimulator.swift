import CoreGraphics
import FlickSlidesKit

/// Simulerar tangentbordstryck via CGEvent.
final class KeyboardSimulator {
    private var lastCommandTime: Date = .distantPast
    private let debounceInterval: TimeInterval

    init(debounceInterval: TimeInterval = FlickSlidesConstants.macCommandCooldown) {
        self.debounceInterval = debounceInterval
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
    func handleCommand(_ command: PresentationCommand) -> Bool {
        return sendKey(CGKeyCode(command.keyCode))
    }
}

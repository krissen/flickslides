import Foundation

/// Koordinerar kommunikation mellan Watch och Mac.
final class BridgeCoordinator: ObservableObject {
    static let shared = BridgeCoordinator()

    enum CommandSource: String {
        case watch = "watch"
        case phone = "phone"
    }

    struct CommandLogEntry: Identifiable {
        let id = UUID()
        let command: String
        let source: CommandSource
        let timestamp: Date
        let status: String
        let latencyMs: Int?
    }

    @Published var commandLog: [CommandLogEntry] = []

    private init() {}

    func forwardToMac(command: String, timestamp: Date, source: CommandSource = .watch) {
        forwardToMac(command: command, timestamp: timestamp, gestureTimestamp: nil, source: source, replyHandler: nil)
    }

    func forwardToMac(
        command: String,
        timestamp: Date,
        gestureTimestamp: TimeInterval?,
        source: CommandSource = .watch,
        replyHandler: ((TimeInterval) -> Void)?
    ) {
        let macManager = MacConnectionManager.shared

        guard macManager.connectedMac != nil else {
            addLog(command: command, source: source, timestamp: timestamp, status: "❌ Ingen Mac", latencyMs: nil)
            return
        }

        macManager.sendCommand(command, source: source, gestureTimestamp: gestureTimestamp) { executedTimestamp in
            // Beräkna total latens om vi har gestureTimestamp
            var latencyMs: Int? = nil
            if let gestureTs = gestureTimestamp {
                latencyMs = Int((executedTimestamp - gestureTs) * 1000)
                print("[BridgeCoordinator] End-to-end latency: \(latencyMs!)ms")
            }

            self.addLog(command: command, source: source, timestamp: timestamp, status: "✓ Utfört", latencyMs: latencyMs)

            // Svara tillbaka till Watch
            replyHandler?(executedTimestamp)
        }
    }

    private func addLog(command: String, source: CommandSource, timestamp: Date, status: String, latencyMs: Int?) {
        DispatchQueue.main.async {
            let entry = CommandLogEntry(command: command, source: source, timestamp: timestamp, status: status, latencyMs: latencyMs)
            self.commandLog.insert(entry, at: 0)

            // Behåll max 50 loggar
            if self.commandLog.count > 50 {
                self.commandLog.removeLast()
            }
        }
    }
}

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
    }

    @Published var commandLog: [CommandLogEntry] = []

    private init() {}

    func forwardToMac(command: String, timestamp: Date, source: CommandSource = .watch) {
        let macManager = MacConnectionManager.shared

        guard macManager.connectedMac != nil else {
            addLog(command: command, source: source, timestamp: timestamp, status: "❌ Ingen Mac")
            return
        }

        macManager.sendCommand(command, source: source)
        addLog(command: command, source: source, timestamp: timestamp, status: "✓ Skickat")
    }

    private func addLog(command: String, source: CommandSource, timestamp: Date, status: String) {
        DispatchQueue.main.async {
            let entry = CommandLogEntry(command: command, source: source, timestamp: timestamp, status: status)
            self.commandLog.insert(entry, at: 0)

            // Behåll max 50 loggar
            if self.commandLog.count > 50 {
                self.commandLog.removeLast()
            }
        }
    }
}

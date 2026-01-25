import Foundation

/// Koordinerar kommunikation mellan Watch och Mac.
final class BridgeCoordinator: ObservableObject {
    static let shared = BridgeCoordinator()

    struct CommandLogEntry: Identifiable {
        let id = UUID()
        let command: String
        let timestamp: Date
        let status: String
    }

    @Published var commandLog: [CommandLogEntry] = []

    private init() {}

    func forwardToMac(command: String, timestamp: Date) {
        let macManager = MacConnectionManager.shared

        guard macManager.connectedMac != nil else {
            addLog(command: command, timestamp: timestamp, status: "❌ Ingen Mac")
            return
        }

        macManager.sendCommand(command)
        addLog(command: command, timestamp: timestamp, status: "✓ Skickat")
    }

    private func addLog(command: String, timestamp: Date, status: String) {
        DispatchQueue.main.async {
            let entry = CommandLogEntry(command: command, timestamp: timestamp, status: status)
            self.commandLog.insert(entry, at: 0)

            // Behåll max 50 loggar
            if self.commandLog.count > 50 {
                self.commandLog.removeLast()
            }
        }
    }
}

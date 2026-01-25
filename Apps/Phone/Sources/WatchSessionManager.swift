import Foundation
import WatchConnectivity

/// Hanterar WCSession-kommunikation med Apple Watch.
final class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()

    @Published var isWatchReachable = false
    @Published var lastCommand: String?
    @Published var lastCommandTimestamp: Date?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
            print("[WatchSession] Activated: \(activationState.rawValue), reachable: \(session.isReachable)")
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
            print("[WatchSession] Reachability changed: \(session.isReachable)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        print("[WatchSession] Did become inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        // Återaktivera för att stödja Watch-byte
        WCSession.default.activate()
        print("[WatchSession] Did deactivate, reactivating")
    }

    /// Tar emot meddelanden från Watch (realtid)
    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any]) {
        guard let command = message["command"] as? String else { return }

        let timestamp = Date()
        DispatchQueue.main.async {
            self.lastCommand = command
            self.lastCommandTimestamp = timestamp
        }

        // Vidarebefordra till Mac
        BridgeCoordinator.shared.forwardToMac(command: command, timestamp: timestamp)
        print("[WatchSession] Received: \(command)")
    }

    /// Tar emot meddelanden med reply handler
    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        guard let command = message["command"] as? String else {
            replyHandler(["error": "Invalid command"])
            return
        }

        let receiveTimestamp = Date()

        DispatchQueue.main.async {
            self.lastCommand = command
            self.lastCommandTimestamp = receiveTimestamp
        }

        // Vidarebefordra till Mac
        BridgeCoordinator.shared.forwardToMac(command: command, timestamp: receiveTimestamp)

        // Bekräfta till Watch
        replyHandler([
            "ack": command,
            "timestamp": receiveTimestamp.timeIntervalSince1970
        ])

        print("[WatchSession] Received with reply: \(command)")
    }
}

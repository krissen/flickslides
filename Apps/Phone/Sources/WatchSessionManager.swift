import Foundation
import WatchConnectivity
import FlickSlidesKit

/// Hanterar WCSession-kommunikation med Apple Watch.
final class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()

    @Published var isWatchReachable = false
    @Published var lastCommand: String?
    @Published var lastCommandTimestamp: Date?

    // MARK: - Calibration

    /// Callback för kalibreringsmeddelanden från Watch.
    var onCalibrationMessage: ((CalibrationMessage) -> Void)?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - Send to Watch

    /// Skickar ett kalibreringsmeddelande till Watch.
    func sendCalibrationMessage(_ message: CalibrationMessage, completion: ((Error?) -> Void)? = nil) {
        guard WCSession.default.isReachable else {
            completion?(WatchSessionError.watchNotReachable)
            return
        }

        let dict = message.toDictionary()

        WCSession.default.sendMessage(dict, replyHandler: { _ in
            completion?(nil)
        }, errorHandler: { error in
            print("[WatchSession] Failed to send calibration message: \(error)")
            completion?(error)
        })
    }

    enum WatchSessionError: Error, LocalizedError {
        case watchNotReachable

        var errorDescription: String? {
            switch self {
            case .watchNotReachable:
                return "Watch ej nåbar"
            }
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
        // Kolla om det är ett kalibreringsmeddelande
        if let calibrationMessage = CalibrationMessage.fromDictionary(message) {
            DispatchQueue.main.async {
                self.onCalibrationMessage?(calibrationMessage)
            }
            print("[WatchSession] Received calibration message: \(calibrationMessage)")
            return
        }

        // Presentation command
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
        // Kolla om det är ett kalibreringsmeddelande
        if let calibrationMessage = CalibrationMessage.fromDictionary(message) {
            DispatchQueue.main.async {
                self.onCalibrationMessage?(calibrationMessage)
            }
            replyHandler(["ack": true])
            print("[WatchSession] Received calibration message with reply: \(calibrationMessage)")
            return
        }

        // Presentation command
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

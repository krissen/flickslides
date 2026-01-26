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

    // MARK: - Settings Sync

    /// Skickar uppdaterade inställningar till Watch.
    /// Använder `transferUserInfo` för garanterad leverans även om Watch inte är nåbar just nu.
    func syncSettings(
        accelerationThreshold: Double? = nil,
        rotationThreshold: Double? = nil,
        debounceInterval: Double? = nil,
        watchOnRightWrist: Bool? = nil
    ) {
        var payload: [String: Any] = ["type": "settingsUpdate"]

        if let accel = accelerationThreshold {
            payload["accelerationThreshold"] = accel
        }
        if let rot = rotationThreshold {
            payload["rotationThreshold"] = rot
        }
        if let debounce = debounceInterval {
            payload["gestureDebounceInterval"] = debounce
        }
        if let wrist = watchOnRightWrist {
            payload["watchOnRightWrist"] = wrist
        }

        // Om Watch är nåbar, skicka direkt för snabb respons
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil) { error in
                print("[WatchSession] sendMessage failed, queuing via transferUserInfo: \(error)")
                // Fallback till transferUserInfo vid fel
                WCSession.default.transferUserInfo(payload)
            }
            print("[WatchSession] Sent settings update via sendMessage")
        } else {
            // Köa för leverans när Watch blir tillgänglig
            WCSession.default.transferUserInfo(payload)
            print("[WatchSession] Queued settings update via transferUserInfo")
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
        let gestureTimestamp = message["gestureTimestamp"] as? TimeInterval

        // Logga Watch→Phone latens
        if let gestureTs = gestureTimestamp {
            let watchToPhoneMs = (receiveTimestamp.timeIntervalSince1970 - gestureTs) * 1000
            print("[WatchSession] Watch→Phone latency: \(String(format: "%.0f", watchToPhoneMs))ms")
        }

        DispatchQueue.main.async {
            self.lastCommand = command
            self.lastCommandTimestamp = receiveTimestamp
        }

        // Vidarebefordra till Mac med original gestureTimestamp
        BridgeCoordinator.shared.forwardToMac(
            command: command,
            timestamp: receiveTimestamp,
            gestureTimestamp: gestureTimestamp,
            replyHandler: { executedTimestamp in
                // Skicka tillbaka executedTimestamp till Watch
                replyHandler([
                    "ack": command,
                    "timestamp": receiveTimestamp.timeIntervalSince1970,
                    "executedTimestamp": executedTimestamp
                ])
            }
        )

        print("[WatchSession] Received with reply: \(command)")
    }
}

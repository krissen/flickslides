import Foundation
import HealthKit
import WatchConnectivity
import WatchKit
import FlickSlidesKit

/// Hanterar presentationsläge och WCSession-kommunikation.
/// Använder HKWorkoutSession för att hålla sensorer aktiva i bakgrunden.
@MainActor
final class PresentationManager: NSObject, ObservableObject {

    static let shared = PresentationManager()

    // MARK: - Published State

    @Published private(set) var isPresentationMode = false
    @Published private(set) var isTransitioning = false  // Loading-state för start/stopp
    @Published private(set) var connectionState: String = "Ej ansluten"
    @Published private(set) var lastCommand: String?

    // MARK: - Dependencies

    private let gestureDetector = GestureDetector()

    // MARK: - HealthKit

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    // MARK: - Initialization

    private override init() {
        super.init()
        setupWCSession()
    }

    // MARK: - WCSession Setup

    private func setupWCSession() {
        guard WCSession.isSupported() else {
            print("[PresentationManager] WCSession not supported")
            return
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Workout Session (för bakgrundsaktivitet)

    private func startWorkoutSession() async throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        configuration.locationType = .indoor

        let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()

        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )

        session.delegate = self
        builder.delegate = self

        self.workoutSession = session
        self.workoutBuilder = builder

        session.startActivity(with: Date())
        try await builder.beginCollection(at: Date())

        print("[PresentationManager] Workout session started (background sensors enabled)")
    }

    private func stopWorkoutSession() async {
        guard let session = workoutSession, let builder = workoutBuilder else { return }

        session.end()

        // Kolla om användaren vill spara workout till Hälsa-appen
        let defaults = UserDefaults(suiteName: "group.com.kristianniemi.FlickSlides") ?? .standard
        let saveWorkout = defaults.bool(forKey: "saveWorkoutsToHealth")

        do {
            try await builder.endCollection(at: Date())

            if saveWorkout {
                // Spara workoutet till Health-appen
                try await builder.finishWorkout()
                print("[PresentationManager] Workout session ended and saved to Health")
            } else {
                // Kasta workoutet utan att spara
                builder.discardWorkout()
                print("[PresentationManager] Workout session ended (discarded, not saved to Health)")
            }
        } catch {
            print("[PresentationManager] Failed to end workout: \(error)")
        }

        self.workoutSession = nil
        self.workoutBuilder = nil
    }

    private func requestHealthKitAuthorization() async {
        let workoutType = HKQuantityType.workoutType()

        do {
            try await healthStore.requestAuthorization(toShare: [workoutType], read: [])
            print("[PresentationManager] HealthKit authorization granted")
        } catch {
            print("[PresentationManager] HealthKit authorization failed: \(error)")
        }
    }

    // MARK: - Presentation Control

    func startPresentation() async {
        guard !isPresentationMode && !isTransitioning else { return }

        isTransitioning = true
        WKInterfaceDevice.current().play(.click)  // Omedelbar feedback

        // Begär HealthKit-auktorisering
        await requestHealthKitAuthorization()

        // Starta workout session för bakgrundsaktivitet
        do {
            try await startWorkoutSession()
        } catch {
            print("[PresentationManager] Failed to start workout session: \(error)")
            print("[PresentationManager] Continuing without background support")
        }

        // Ladda om konfiguration (hämta ev. nya inställningar från iPhone)
        gestureDetector.reloadConfiguration()

        // Ladda om DTW-mallar (om kalibrering gjorts)
        gestureDetector.reloadDTWTemplates()

        // Starta gestdetektering
        gestureDetector.start { [weak self] gesture in
            Task { @MainActor in
                self?.handleGesture(gesture)
            }
        }

        isPresentationMode = true
        isTransitioning = false

        // Haptisk feedback
        WKInterfaceDevice.current().play(.start)
        print("[PresentationManager] Presentation started")
    }

    func stopPresentation() async {
        guard isPresentationMode && !isTransitioning else { return }

        isTransitioning = true
        WKInterfaceDevice.current().play(.click)  // Omedelbar feedback

        gestureDetector.stop()

        // Stoppa workout session
        await stopWorkoutSession()

        isPresentationMode = false
        isTransitioning = false

        // Haptisk feedback
        WKInterfaceDevice.current().play(.stop)
        print("[PresentationManager] Presentation stopped")
    }

    // MARK: - Gesture Handling

    private func handleGesture(_ gesture: GestureDetector.DetectedGesture) {
        let command: String

        switch gesture {
        case .flick(let direction):
            switch direction {
            case .forward:
                command = "NEXT"
            case .backward:
                command = "PREV"
            }
        case .doublePunch:
            command = "BLACKOUT"
        }

        sendCommand(command)

        // Haptisk feedback
        WKInterfaceDevice.current().play(.success)
    }

    // MARK: - WCSession Communication

    private func sendCommand(_ command: String) {
        guard WCSession.default.isReachable else {
            print("[PresentationManager] iPhone not reachable")
            connectionState = "iPhone ej nåbar"
            return
        }

        let message = ["command": command]

        WCSession.default.sendMessage(message, replyHandler: { reply in
            Task { @MainActor in
                self.lastCommand = command
                print("[PresentationManager] Command \(command) acknowledged")
            }
        }, errorHandler: { error in
            Task { @MainActor in
                print("[PresentationManager] Failed to send command: \(error)")
                self.connectionState = "Sändning misslyckades"
            }
        })
    }
}

// MARK: - WCSessionDelegate

extension PresentationManager: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            switch activationState {
            case .activated:
                connectionState = "Ansluten"
            case .inactive:
                connectionState = "Inaktiv"
            case .notActivated:
                connectionState = "Ej aktiverad"
            @unknown default:
                connectionState = "Okänd"
            }
            print("[PresentationManager] WCSession state: \(connectionState)")
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            connectionState = session.isReachable ? "Ansluten" : "Frånkopplad"
            print("[PresentationManager] Reachability changed: \(connectionState)")
        }
    }

    /// Tar emot meddelanden från Phone.
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        // Kolla om det är ett kalibreringsmeddelande
        if let calibrationMessage = CalibrationMessage.fromDictionary(message) {
            Task { @MainActor in
                WatchCalibrationCoordinator.shared.handleMessage(calibrationMessage)
            }
            return
        }

        // Övriga meddelanden (framtida utökning)
        print("[PresentationManager] Received unknown message: \(message)")
    }

    /// Tar emot meddelanden med reply handler.
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        // Kolla om det är ett kalibreringsmeddelande
        if let calibrationMessage = CalibrationMessage.fromDictionary(message) {
            Task { @MainActor in
                WatchCalibrationCoordinator.shared.handleMessage(calibrationMessage)
            }
            replyHandler(["ack": true])
            return
        }

        // Övriga meddelanden
        replyHandler(["error": "Unknown message type"])
    }

    /// Tar emot userInfo från Phone (används för att överföra gestmallar och inställningar).
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        // Kolla om det är gestmallar
        if let data = userInfo["gestureTemplates"] as? Data {
            do {
                let templates = try JSONDecoder().decode([GestureTemplate].self, from: data)
                let store = GestureTemplateStore()
                store.save(templates)
                print("[PresentationManager] Received \(templates.count) gesture templates from Phone")

                // Meddela GestureDetector att ladda om mallarna
                Task { @MainActor in
                    self.gestureDetector.reloadDTWTemplates()
                    print("[PresentationManager] DTW templates reloaded")
                }
            } catch {
                print("[PresentationManager] Failed to decode gesture templates: \(error)")
            }
            return
        }

        // Kolla om kalibrering ska rensas
        if userInfo["clearCalibration"] as? Bool == true {
            let store = GestureTemplateStore()
            store.clear()
            print("[PresentationManager] Calibration cleared by Phone")

            Task { @MainActor in
                self.gestureDetector.reloadDTWTemplates()
                print("[PresentationManager] DTW templates cleared")
            }
            return
        }

        // Kolla om useCalibration toggle ändrats
        if let useCalibration = userInfo["useCalibration"] as? Bool {
            let defaults = UserDefaults(suiteName: "group.com.kristianniemi.FlickSlides") ?? .standard
            defaults.set(useCalibration, forKey: "useCalibration")
            print("[PresentationManager] useCalibration set to \(useCalibration)")

            Task { @MainActor in
                self.gestureDetector.reloadDTWTemplates()
            }
            return
        }

        print("[PresentationManager] Received unknown userInfo: \(userInfo.keys)")
    }
}

// MARK: - HKWorkoutSessionDelegate

extension PresentationManager: HKWorkoutSessionDelegate {

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        print("[PresentationManager] Workout state: \(fromState.rawValue) -> \(toState.rawValue)")
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        print("[PresentationManager] Workout session failed: \(error)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension PresentationManager: HKLiveWorkoutBuilderDelegate {

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        // Vi samlar inte aktivt data, men delegaten krävs
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Vi samlar inte aktivt events, men delegaten krävs
    }
}

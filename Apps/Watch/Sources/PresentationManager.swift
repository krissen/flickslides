import Foundation
import HealthKit
import WatchConnectivity
import WatchKit

/// Hanterar presentationsläge, workout session och WCSession-kommunikation.
@MainActor
final class PresentationManager: NSObject, ObservableObject {

    static let shared = PresentationManager()

    // MARK: - Published State

    @Published private(set) var isPresentationMode = false
    @Published private(set) var connectionState: String = "Ej ansluten"
    @Published private(set) var lastCommand: String?

    // MARK: - Dependencies

    private let gestureDetector = GestureDetector()
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

    // MARK: - Presentation Control

    func startPresentation() async {
        guard !isPresentationMode else { return }

        // Starta workout session för bakgrundsaktivitet
        do {
            try await startWorkoutSession()
        } catch {
            print("[PresentationManager] Failed to start workout: \(error)")
            // Fortsätt ändå - fungerar i förgrund
        }

        // Starta gestdetektering
        gestureDetector.start { [weak self] gesture in
            Task { @MainActor in
                self?.handleGesture(gesture)
            }
        }

        isPresentationMode = true

        // Haptisk feedback
        WKInterfaceDevice.current().play(.start)
        print("[PresentationManager] Presentation started")
    }

    func stopPresentation() async {
        guard isPresentationMode else { return }

        gestureDetector.stop()

        if let session = workoutSession {
            session.end()
            workoutSession = nil
        }

        isPresentationMode = false

        // Haptisk feedback
        WKInterfaceDevice.current().play(.stop)
        print("[PresentationManager] Presentation stopped")
    }

    // MARK: - Workout Session

    private func startWorkoutSession() async throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        configuration.locationType = .indoor

        workoutSession = try HKWorkoutSession(
            healthStore: healthStore,
            configuration: configuration
        )
        workoutBuilder = workoutSession?.associatedWorkoutBuilder()
        workoutBuilder?.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )

        workoutSession?.startActivity(with: Date())
        try await workoutBuilder?.beginCollection(at: Date())

        print("[PresentationManager] Workout session started")
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
}

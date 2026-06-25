import Foundation
import WatchConnectivity
import WatchKit
import FlickSlidesKit

/// Koordinerar kalibrering på Watch-sidan via WCSession.
///
/// Tar emot kommandon från Phone och delegerar till CalibrationRecorder.
/// Skickar tillbaka resultat till Phone.
@MainActor
final class WatchCalibrationCoordinator: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = WatchCalibrationCoordinator()

    // MARK: - Published State

    @Published private(set) var isCalibrationActive = false
    @Published private(set) var isCalibrationComplete = false
    @Published private(set) var currentGestureType: GestureLabel?
    @Published private(set) var currentSampleIndex: Int = 0
    @Published private(set) var isRecording = false
    @Published private(set) var isWaitingForIdle = false
    @Published private(set) var isReadyForGesture = false
    @Published private(set) var lastError: String?

    /// Visar dialog för att acceptera/avvisa kalibreringsbegäran från Phone.
    @Published var showCalibrationRequest = false

    // MARK: - Dependencies

    private let recorder = CalibrationRecorder()

    // MARK: - Initialization

    private override init() {
        super.init()
        setupBindings()
    }

    private func setupBindings() {
        // Koppla meddelande-callback
        recorder.onSendMessage = { [weak self] message in
            Task { @MainActor in
                self?.sendMessage(message)
            }
        }

        // Observera recorder state
        Task { @MainActor in
            for await isRecording in recorder.$isRecording.values {
                self.isRecording = isRecording
            }
        }

        Task { @MainActor in
            for await gestureType in recorder.$currentGestureType.values {
                self.currentGestureType = gestureType
            }
        }

        Task { @MainActor in
            for await index in recorder.$currentSampleIndex.values {
                self.currentSampleIndex = index
            }
        }

        Task { @MainActor in
            for await isWaitingForIdle in recorder.$isWaitingForIdle.values {
                self.isWaitingForIdle = isWaitingForIdle
            }
        }

        Task { @MainActor in
            for await isReadyForGesture in recorder.$isReadyForGesture.values {
                self.isReadyForGesture = isReadyForGesture
            }
        }
    }

    // MARK: - Message Handling

    /// Hanterar inkommande kalibreringsmeddelande från Phone.
    func handleMessage(_ message: CalibrationMessage) {
        log("Received: \(message)")

        switch message {
        case .calibrationRequested:
            handleCalibrationRequested()

        case .startRecording(let gestureType, let sampleIndex):
            handleStartRecording(gestureType: gestureType, sampleIndex: sampleIndex)

        case .stopRecording:
            handleStopRecording()

        case .calibrationAborted:
            handleCalibrationAborted()

        case .calibrationComplete:
            handleCalibrationComplete()

        case .ping:
            handlePing()

        // Meddelanden som Watch skickar, inte tar emot
        case .calibrationAccepted, .calibrationDeclined,
             .recordingStarted, .sampleRecorded, .recordingFailed,
             .pong, .watchReady, .watchDismissed, .readyForGesture:
            log("Unexpected message type received: \(message)")
        }
    }

    // MARK: - Command Handlers

    private func handleCalibrationRequested() {
        // Visa dialog på Watch
        showCalibrationRequest = true
        WKInterfaceDevice.current().play(.notification)
        log("Calibration requested by Phone - showing dialog")
    }

    /// Användaren accepterade kalibreringsbegäran.
    func acceptCalibrationRequest() {
        showCalibrationRequest = false
        sendMessage(.calibrationAccepted)
        log("Calibration accepted by user")
    }

    /// Användaren avvisade kalibreringsbegäran.
    func declineCalibrationRequest() {
        showCalibrationRequest = false
        sendMessage(.calibrationDeclined)
        log("Calibration declined by user")
    }

    private func handleStartRecording(gestureType: GestureLabel, sampleIndex: Int) {
        isCalibrationActive = true
        lastError = nil

        // Skicka bekräftelse att inspelning startar
        sendMessage(.recordingStarted)

        recorder.startRecording(gestureType: gestureType, sampleIndex: sampleIndex) { [weak self] result in
            Task { @MainActor in
                self?.handleRecordingResult(result)
            }
        }
    }

    private func handleStopRecording() {
        recorder.stopRecording()
    }

    private func handleCalibrationAborted() {
        recorder.stopRecording()
        resetState()
        log("Calibration aborted by Phone")
    }

    private func handleCalibrationComplete() {
        recorder.stopRecording()
        isCalibrationActive = false
        isCalibrationComplete = true
        isRecording = false
        isWaitingForIdle = false
        isReadyForGesture = false
        currentGestureType = nil
        WKInterfaceDevice.current().play(WKHapticType.success)
        log("Calibration complete!")
    }

    /// Återställer all state till utgångsläge.
    private func resetState() {
        isCalibrationActive = false
        isCalibrationComplete = false
        currentGestureType = nil
        currentSampleIndex = 0
        isRecording = false
        isWaitingForIdle = false
        isReadyForGesture = false
        lastError = nil
    }

    private func handlePing() {
        sendMessage(.pong)
    }

    private func handleRecordingResult(_ result: Result<MotionSampleBatch, CalibrationRecorder.RecordingError>) {
        switch result {
        case .success(let batch):
            sendMessage(.sampleRecorded(batch: batch))
            log("Sample sent to Phone: \(batch.sampleCount) samples")

        case .failure(let error):
            lastError = error.localizedDescription
            sendMessage(.recordingFailed(reason: error.localizedDescription))
            log("Recording failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Outgoing Messages

    private func sendMessage(_ message: CalibrationMessage) {
        guard WCSession.default.isReachable else {
            log("Cannot send message: Phone not reachable")
            return
        }

        let dict = message.toDictionary()

        WCSession.default.sendMessage(dict, replyHandler: nil) { [weak self] error in
            Task { @MainActor in
                self?.log("Failed to send message: \(error.localizedDescription)")
            }
        }
    }

    /// Meddelar Phone att Watch är redo för kalibrering.
    func notifyWatchReady() {
        isCalibrationActive = true
        sendMessage(.watchReady)
        log("Notified Phone: Watch ready")
    }

    /// Meddelar Phone att Watch har lämnat kalibreringsläge.
    func notifyWatchDismissed() {
        recorder.stopRecording()
        resetState()
        sendMessage(.watchDismissed)
        log("Notified Phone: Watch dismissed")
    }

    private func log(_ message: String) {
        print("[WatchCalibrationCoordinator] \(message)")
    }
}

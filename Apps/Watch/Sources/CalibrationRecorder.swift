import Foundation
import CoreMotion
import WatchKit
import FlickSlidesKit

/// Spelar in motion-data på kommando från Phone.
///
/// Denna klass hanterar endast inspelning av sensordata. All orkestrering och
/// analys sker på Phone-sidan.
///
/// Flödet:
/// 1. Phone skickar startRecording
/// 2. Watch väntar på "idle" (armen vilande)
/// 3. Watch skickar readyForGesture till Phone
/// 4. Watch väntar på geststart (hög acceleration)
/// 5. Watch spelar in gesten
/// 6. Watch skickar sampleRecorded till Phone
@MainActor
final class CalibrationRecorder: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isRecording = false
    @Published private(set) var isWaitingForIdle = false
    @Published private(set) var isReadyForGesture = false
    @Published private(set) var currentGestureType: GestureLabel?
    @Published private(set) var currentSampleIndex: Int = 0

    // MARK: - Configuration (from FlickSlidesConstants)

    private typealias C = FlickSlidesConstants

    // Callback för att skicka meddelanden till Phone
    var onSendMessage: ((CalibrationMessage) -> Void)?

    // MARK: - Private Properties

    private let motionManager = CMMotionManager()
    private var currentSamples: [MotionSample] = []
    private var gestureStartTime: Date?
    private var recordingStartTime: Date?
    private var idleStartTime: Date?
    private var hasSignaledReady = false
    private var onRecordingComplete: ((Result<MotionSampleBatch, RecordingError>) -> Void)?

    // Pre-buffer för att fånga början av gesten
    private var preBuffer: [(Date, CMDeviceMotion)] = []
    private let preBufferSize = 10  // Antal samples att behålla innan geststart (200ms vid 50Hz)

    // Race condition-skydd: sätts före state-rensning i stopRecording()
    // så att in-flight motion updates ignoreras
    private var isStopping = false

    // MARK: - Errors

    enum RecordingError: Error, LocalizedError {
        case motionNotAvailable
        case alreadyRecording
        case timeout
        case tooFewSamples
        case cancelled

        var errorDescription: String? {
            switch self {
            case .motionNotAvailable:
                return "Motion-sensorer inte tillgängliga"
            case .alreadyRecording:
                return "Inspelning pågår redan"
            case .timeout:
                return "Ingen gest detekterad"
            case .tooFewSamples:
                return "För kort gest"
            case .cancelled:
                return "Inspelning avbruten"
            }
        }
    }

    // MARK: - Public API

    /// Startar inspelning av en gest.
    func startRecording(
        gestureType: GestureLabel,
        sampleIndex: Int,
        completion: @escaping (Result<MotionSampleBatch, RecordingError>) -> Void
    ) {
        guard !isRecording else {
            completion(.failure(.alreadyRecording))
            return
        }

        guard motionManager.isDeviceMotionAvailable else {
            completion(.failure(.motionNotAvailable))
            return
        }

        currentGestureType = gestureType
        currentSampleIndex = sampleIndex
        isStopping = false  // Återställ race condition-flagga
        isRecording = true
        isWaitingForIdle = true
        isReadyForGesture = false
        hasSignaledReady = false
        currentSamples.removeAll()
        preBuffer.removeAll()
        gestureStartTime = nil
        idleStartTime = nil
        recordingStartTime = Date()
        onRecordingComplete = completion

        // Haptisk feedback
        WKInterfaceDevice.current().play(.start)
        log("Waiting for idle...")

        // Starta motion updates
        motionManager.deviceMotionUpdateInterval = 1.0 / C.sensorSamplingRate
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self, let motion else { return }
            Task { @MainActor in
                self.processMotion(motion)
            }
        }

        log("Started recording: \(gestureType) #\(sampleIndex)")
    }

    /// Stoppar pågående inspelning.
    /// Alltid säker att anropa - stoppar sensorer oavsett nuvarande state.
    func stopRecording() {
        // VIKTIGT: Sätt isStopping FÖRST för att blockera in-flight motion updates
        // som kan anlända efter att vi börjat rensa state
        isStopping = true

        // Stoppa ALLTID sensorer - även om isRecording är false
        // (kan ha blivit ur synk)
        motionManager.stopDeviceMotionUpdates()

        let wasRecording = isRecording
        isRecording = false
        isWaitingForIdle = false
        isReadyForGesture = false
        hasSignaledReady = false
        currentGestureType = nil
        currentSamples.removeAll()
        preBuffer.removeAll()
        gestureStartTime = nil
        idleStartTime = nil
        recordingStartTime = nil

        if wasRecording {
            onRecordingComplete?(.failure(.cancelled))
        }
        onRecordingComplete = nil

        log("Recording stopped/cancelled (wasRecording=\(wasRecording))")
    }

    // MARK: - Motion Processing

    private func processMotion(_ motion: CMDeviceMotion) {
        // Race condition-skydd: ignorera motion updates som anlände
        // efter att stopRecording() påbörjades
        guard !isStopping else { return }

        let now = Date()
        let acc = motion.userAcceleration
        let rot = motion.rotationRate
        let accMagnitude = sqrt(acc.x * acc.x + acc.y * acc.y + acc.z * acc.z)

        // Timeout-kontroll
        if let recordStart = recordingStartTime,
           now.timeIntervalSince(recordStart) > C.calibrationRecordingTimeout {
            finishRecording(with: .failure(.timeout))
            return
        }

        // Fas 1: Vänta på idle (armen vilande)
        if isWaitingForIdle {
            if accMagnitude < C.calibrationIdleThreshold {
                // Låg acceleration - kan vara idle
                if idleStartTime == nil {
                    idleStartTime = now
                } else if now.timeIntervalSince(idleStartTime!) >= C.calibrationIdleRequiredDuration {
                    // Tillräckligt länge med låg acceleration - vi är idle!
                    isWaitingForIdle = false
                    isReadyForGesture = true

                    if !hasSignaledReady {
                        hasSignaledReady = true
                        WKInterfaceDevice.current().play(.click)
                        onSendMessage?(.readyForGesture)
                        log("Idle detected - ready for gesture")
                    }
                }
            } else {
                // Fortfarande rörelse - återställ idle timer
                idleStartTime = nil
            }
            return
        }

        // Fas 2: Buffra kontinuerligt (för att fånga början av gesten)
        if gestureStartTime == nil {
            preBuffer.append((now, motion))
            if preBuffer.count > preBufferSize {
                preBuffer.removeFirst()
            }
        }

        // Fas 3: Detektera geststart
        if gestureStartTime == nil && accMagnitude > C.calibrationAccelerationThreshold {
            // Använd första sample i pre-buffern som startpunkt
            let actualStartTime = preBuffer.first?.0 ?? now
            gestureStartTime = actualStartTime
            isReadyForGesture = false

            // Konvertera pre-buffer till samples
            currentSamples = preBuffer.map { (timestamp, m) in
                MotionSample(
                    timestamp: timestamp.timeIntervalSince(actualStartTime),
                    accX: m.userAcceleration.x,
                    accY: m.userAcceleration.y,
                    accZ: m.userAcceleration.z,
                    rotX: m.rotationRate.x * 180.0 / .pi,
                    rotY: m.rotationRate.y * 180.0 / .pi,
                    rotZ: m.rotationRate.z * 180.0 / .pi
                )
            }
            preBuffer.removeAll()

            WKInterfaceDevice.current().play(.click)
            log("Gesture start detected (with \(currentSamples.count) pre-buffered samples)")
        }

        // Fas 4: Samla samples under gest
        if let startTime = gestureStartTime {
            let sample = MotionSample(
                timestamp: now.timeIntervalSince(startTime),
                accX: acc.x,
                accY: acc.y,
                accZ: acc.z,
                rotX: rot.x * 180.0 / .pi,
                rotY: rot.y * 180.0 / .pi,
                rotZ: rot.z * 180.0 / .pi
            )
            currentSamples.append(sample)

            // Kontrollera om gesten är klar
            let elapsed = now.timeIntervalSince(startTime)
            let shouldFinish = elapsed > C.calibrationMaxDuration ||
                              (elapsed > C.calibrationMinDuration && accMagnitude < C.calibrationEndThreshold)

            if shouldFinish {
                finishGesture()
            }
        }
    }

    private func finishGesture() {
        guard currentSamples.count >= C.calibrationMinSamples else {
            log("Too few samples: \(currentSamples.count)")
            finishRecording(with: .failure(.tooFewSamples))
            return
        }

        let batch = MotionSampleBatch(samples: currentSamples)
        log("Gesture recorded: \(currentSamples.count) samples, duration=\(String(format: "%.0f", batch.duration * 1000))ms")

        finishRecording(with: .success(batch))
    }

    private func finishRecording(with result: Result<MotionSampleBatch, RecordingError>) {
        // Skydda mot dubbla anrop (kan inträffa om stopRecording() anropas
        // samtidigt som en timeout eller gestslut detekteras)
        guard !isStopping else { return }
        isStopping = true

        motionManager.stopDeviceMotionUpdates()
        isRecording = false
        isWaitingForIdle = false
        isReadyForGesture = false
        hasSignaledReady = false

        // Haptisk feedback
        switch result {
        case .success:
            WKInterfaceDevice.current().play(.success)
        case .failure:
            WKInterfaceDevice.current().play(.failure)
        }

        onRecordingComplete?(result)
        onRecordingComplete = nil
    }

    private func log(_ message: String) {
        print("[CalibrationRecorder] \(message)")
    }
}

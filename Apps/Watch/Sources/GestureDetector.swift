import Foundation
import CoreMotion
import FlickSlidesKit

/// Gestigenkänning baserad på accelerometer/gyroskop-data med state machine.
///
/// ## State Machine
/// ```
/// idle → initiated → peaked → completed
/// ```
///
/// ## Koordinatsystem på Apple Watch
/// ```
///     +Y (upp längs urtavlan)
///      |
/// -----+------ +X (mot kronan/höger)
///     /
///    +Z (ut från skärmen)
/// ```
///
/// ## Rätt rotationsaxel för bladvänd-gest
/// - `rot.x` = pronation/supination (vrid handled inåt/utåt)
/// - Positiv rot.x = pronation (hand vrids inåt) = NEXT
/// - Negativ rot.x = supination (hand vrids utåt) = PREV
///
@MainActor
final class GestureDetector: ObservableObject {

    // MARK: - Constants (from FlickSlidesConstants)

    private typealias C = FlickSlidesConstants

    private enum UserDefaultsKeys {
        static let accelerationThreshold = "accelerationThreshold"
        static let rotationThreshold = "rotationThreshold"
        static let gestureDebounceInterval = "gestureDebounceInterval"
        static let watchOnRightWrist = "watchOnRightWrist"
    }

    // MARK: - State Machine

    private enum GestureState: CustomStringConvertible {
        case idle
        case initiated(startTime: Date, direction: GestureDirection)
        case peaked(startTime: Date, direction: GestureDirection, peakAcceleration: Double)

        var description: String {
            switch self {
            case .idle:
                return "idle"
            case .initiated(_, let direction):
                return "initiated(\(direction))"
            case .peaked(_, let direction, let peak):
                return "peaked(\(direction), peak=\(String(format: "%.2f", peak))g)"
            }
        }
    }

    private enum GestureDirection {
        case forward   // NEXT - pronation (positiv rot.x)
        case backward  // PREV - supination (negativ rot.x)
    }

    // MARK: - Published State

    @Published private(set) var isActive = false
    @Published private(set) var lastDetectedGesture: DetectedGesture?
    @Published private(set) var currentAcceleration: Double = 0
    @Published private(set) var currentRotationRate: Double = 0  // grader/sekund

    // MARK: - Configuration

    struct Configuration {
        /// Minimum acceleration för att räknas som gest (g)
        var accelerationThreshold: Double

        /// Minimum rotation för handflick (grader/sekund)
        var rotationThreshold: Double

        /// Cooldown mellan gester (sekunder)
        var debounceInterval: TimeInterval

        /// Sampling-frekvens (Hz)
        var samplingRate: Double

        /// Klockan sitter på höger handled (påverkar rotationsriktning)
        var watchOnRightWrist: Bool

        /// Max tid för en gest från initiation till completion (sekunder)
        var gestureTimeout: TimeInterval

        /// Skapar konfiguration med värden från UserDefaults (med app group för delning med iPhone)
        static func fromUserDefaults() -> Configuration {
            let defaults = UserDefaults(suiteName: "group.com.kristianniemi.FlickSlides") ?? .standard

            let accelThreshold = defaults.object(forKey: UserDefaultsKeys.accelerationThreshold) as? Double
                ?? C.accelerationThreshold
            let rotThreshold = defaults.object(forKey: UserDefaultsKeys.rotationThreshold) as? Double
                ?? C.rotationThreshold
            let debounce = defaults.object(forKey: UserDefaultsKeys.gestureDebounceInterval) as? Double
                ?? C.gestureDebounceInterval
            let rightWrist = defaults.object(forKey: UserDefaultsKeys.watchOnRightWrist) as? Bool ?? true

            return Configuration(
                accelerationThreshold: accelThreshold,
                rotationThreshold: rotThreshold,
                debounceInterval: debounce,
                samplingRate: C.sensorSamplingRate,
                watchOnRightWrist: rightWrist,
                gestureTimeout: C.gestureTimeout
            )
        }
    }

    var configuration: Configuration

    // MARK: - Detected Gesture

    enum DetectedGesture: Equatable {
        case flick(direction: FlickDirection)
        case doublePunch

        enum FlickDirection {
            case forward   // Nästa slide
            case backward  // Föregående slide
        }
    }

    // MARK: - Private Properties

    private let motionManager = CMMotionManager()
    private var lastGestureTime: Date = .distantPast
    private var onGestureDetected: ((DetectedGesture) -> Void)?

    // State machine
    private var gestureState: GestureState = .idle

    // Peak detection window
    private var recentAccelerations: [Double] = []
    private var maxAccelerationInGesture: Double = 0
    private let peakWindowSize = 10

    // DTW-baserad gestmatchning
    private let dtwMatcher = DTWMatcher()
    private let templateStore = GestureTemplateStore()
    private var dtwSamples: [MotionSample] = []
    private var dtwGestureStartTime: Date?
    private let dtwConfidenceThreshold: Double = 0.6

    // Pre-buffer för DTW (fångar början av gesten)
    private var dtwPreBuffer: [(Date, CMAcceleration, CMRotationRate)] = []
    private let dtwPreBufferSize = 10  // 200ms vid 50Hz

    /// Avgör om DTW-strategi ska användas (har mallar och är aktiverat)
    private var useDTWStrategy: Bool {
        guard dtwMatcher.hasTemplates else { return false }
        let defaults = UserDefaults(suiteName: "group.com.kristianniemi.FlickSlides") ?? .standard
        return defaults.object(forKey: "useCalibration") as? Bool ?? true
    }

    /// Aktiv strategi (loggas vid start)
    private var currentStrategy: String {
        useDTWStrategy ? "DTW" : "threshold"
    }

    // MARK: - Initialization

    init() {
        self.configuration = Configuration.fromUserDefaults()
        loadDTWTemplates()
    }

    private func loadDTWTemplates() {
        let templates = templateStore.load()
        if !templates.isEmpty {
            dtwMatcher.loadTemplates(templates)
            log("Loaded \(templates.count) DTW templates")
        }
    }

    /// Laddar om DTW-mallar (anropas efter kalibrering)
    func reloadDTWTemplates() {
        loadDTWTemplates()
    }

    // MARK: - Public Methods

    func start(onGesture: @escaping (DetectedGesture) -> Void) {
        guard motionManager.isDeviceMotionAvailable else {
            log("Device motion not available")
            return
        }

        onGestureDetected = onGesture

        let interval = 1.0 / configuration.samplingRate
        motionManager.deviceMotionUpdateInterval = interval

        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self, let motion else { return }
            Task { @MainActor in
                self.processMotion(motion)
            }
        }

        isActive = true
        log("Started with \(configuration.samplingRate) Hz, wrist=\(configuration.watchOnRightWrist ? "right" : "left"), strategy=\(currentStrategy)")
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        isActive = false
        onGestureDetected = nil
        resetState()
        log("Stopped")
    }

    /// Laddar om konfiguration från UserDefaults (anropas t.ex. vid app-aktivering)
    func reloadConfiguration() {
        // Ändra inte config under pågående gest - kan orsaka inkonsekvent beteende
        guard case .idle = gestureState, dtwGestureStartTime == nil else {
            log("Configuration reload skipped - gesture in progress")
            return
        }
        configuration = Configuration.fromUserDefaults()
        log("Configuration reloaded: accel=\(configuration.accelerationThreshold)g, rot=\(configuration.rotationThreshold)°/s, debounce=\(configuration.debounceInterval)s, wrist=\(configuration.watchOnRightWrist ? "right" : "left")")
    }

    // MARK: - Motion Processing

    private func processMotion(_ motion: CMDeviceMotion) {
        let now = Date()

        let acc = motion.userAcceleration
        let rot = motion.rotationRate

        // Beräkna magnituder
        let accMagnitude = sqrt(acc.x * acc.x + acc.y * acc.y + acc.z * acc.z)
        currentAcceleration = accMagnitude

        // Rotation X i grader/sekund (primär axel för bladvänd)
        let rotXDeg = rot.x * 180.0 / .pi

        // Rotation magnitude för display
        let rotMagnitudeRad = sqrt(rot.x * rot.x + rot.y * rot.y + rot.z * rot.z)
        currentRotationRate = rotMagnitudeRad * 180.0 / .pi

        // Effektiv rotation med hänsyn till vilken handled
        // Vänster handled: rotation är inverterad relativt klockan
        let effectiveRotX = configuration.watchOnRightWrist ? rotXDeg : -rotXDeg

        // Håll koll på senaste värden för peak-detection
        updateAccelerationWindow(accMagnitude)

        // Kolla debounce
        guard now.timeIntervalSince(lastGestureTime) > configuration.debounceInterval else {
            return
        }

        // Filtrera arm-lyft endast i idle state
        // När en gest väl har startat, låt den fortsätta
        if case .idle = gestureState {
            if isArmLift(acc: acc, rot: rot) {
                return  // Tyst filtrering
            }
        }

        // Kör strategi baserat på om DTW-mallar finns
        if useDTWStrategy {
            // DTW-strategi: samla samples och matcha
            collectDTWSample(now: now, acc: acc, rot: rot, effectiveRotX: effectiveRotX)
            processDTWStrategy(now: now, accMagnitude: accMagnitude)
        } else {
            // Tröskelbaserad strategi: state machine
            processStateMachine(
                now: now,
                acc: acc,
                rot: rot,
                accMagnitude: accMagnitude,
                effectiveRotX: effectiveRotX
            )
        }
    }

    // MARK: - Gesture Start Detection (Unified Trigger)

    /// Avgör om en gest ska initieras baserat på sensordata.
    /// Används av BÅDE DTW och tröskelbaserad strategi för konsekvent beteende.
    ///
    /// Krav för att starta gest:
    /// - X-acceleration dominerar (sidledrörelse)
    /// - X-acceleration > 0.5g
    /// - Rotation i pronation/supination-axeln > 10°/s
    private func shouldStartGesture(acc: CMAcceleration, effectiveRotX: Double) -> Bool {
        let absX = abs(acc.x)
        let absY = abs(acc.y)
        let absZ = abs(acc.z)

        // X måste vara den dominanta axeln för en riktig bladvänd-gest
        let xIsLargest = absX >= absY && absX >= absZ
        let xIsSignificant = absX > 0.5  // Minst 0.5g i sidled

        guard xIsLargest && xIsSignificant else {
            return false
        }

        // Rotation måste ha påbörjats
        let rotationStarted = abs(effectiveRotX) > C.initiationRotationThreshold

        return rotationStarted
    }

    // MARK: - DTW Sample Collection

    private func collectDTWSample(now: Date, acc: CMAcceleration, rot: CMRotationRate, effectiveRotX: Double) {
        // Buffra kontinuerligt för att fånga början av gesten
        if dtwGestureStartTime == nil {
            dtwPreBuffer.append((now, acc, rot))
            if dtwPreBuffer.count > dtwPreBufferSize {
                dtwPreBuffer.removeFirst()
            }
        }

        // Starta sampling med samma trigger som state machine
        if dtwGestureStartTime == nil && shouldStartGesture(acc: acc, effectiveRotX: effectiveRotX) {
            // Använd första sample i pre-buffern som startpunkt
            let actualStartTime = dtwPreBuffer.first?.0 ?? now
            dtwGestureStartTime = actualStartTime

            // Konvertera pre-buffer till samples
            dtwSamples = dtwPreBuffer.map { (timestamp, a, r) in
                MotionSample(
                    timestamp: timestamp.timeIntervalSince(actualStartTime),
                    accX: a.x,
                    accY: a.y,
                    accZ: a.z,
                    rotX: r.x * 180.0 / .pi,
                    rotY: r.y * 180.0 / .pi,
                    rotZ: r.z * 180.0 / .pi
                )
            }
            dtwPreBuffer.removeAll()
            log("DTW sampling started (unified trigger)")
        }

        // Samla samples under aktiv gest
        if let startTime = dtwGestureStartTime {
            let sample = MotionSample(
                timestamp: now.timeIntervalSince(startTime),
                accX: acc.x,
                accY: acc.y,
                accZ: acc.z,
                rotX: rot.x * 180.0 / .pi,
                rotY: rot.y * 180.0 / .pi,
                rotZ: rot.z * 180.0 / .pi
            )
            dtwSamples.append(sample)
        }
    }

    private func tryDTWMatch() -> DetectedGesture? {
        guard dtwSamples.count >= 5 else { return nil }

        let result = dtwMatcher.match(dtwSamples)

        if let label = result.label, result.confidence >= dtwConfidenceThreshold {
            log("DTW match: \(label) confidence=\(String(format: "%.2f", result.confidence)) distance=\(String(format: "%.2f", result.distance))")

            switch label {
            case .flickForward:
                return .flick(direction: .forward)
            case .flickBackward:
                return .flick(direction: .backward)
            case .negative:
                return nil
            }
        }

        return nil
    }

    private func resetDTWState() {
        dtwGestureStartTime = nil
        dtwSamples.removeAll()
        dtwPreBuffer.removeAll()
    }

    // MARK: - DTW Strategy

    /// Processar DTW-strategin (endast anropas när useDTWStrategy == true)
    private func processDTWStrategy(now: Date, accMagnitude: Double) {
        guard let startTime = dtwGestureStartTime else { return }

        let elapsed = now.timeIntervalSince(startTime)
        let samplingComplete = elapsed > 1.0 || (elapsed > 0.15 && accMagnitude < 0.2)

        guard samplingComplete else { return }

        if let gesture = tryDTWMatch() {
            lastGestureTime = now
            lastDetectedGesture = gesture
            onGestureDetected?(gesture)
            log("DETECTED (DTW): \(gesture)")
        } else {
            log("DTW: no match found, samples=\(dtwSamples.count)")
        }

        resetDTWState()
    }

    // MARK: - Threshold Strategy (State Machine)

    /// Processar tröskelbaserad strategi (endast anropas när useDTWStrategy == false)
    private func processStateMachine(
        now: Date,
        acc: CMAcceleration,
        rot: CMRotationRate,
        accMagnitude: Double,
        effectiveRotX: Double
    ) {
        switch gestureState {
        case .idle:
            handleIdleState(now: now, acc: acc, accMagnitude: accMagnitude, effectiveRotX: effectiveRotX)

        case .initiated(let startTime, let direction):
            handleInitiatedState(now: now, startTime: startTime, direction: direction, accMagnitude: accMagnitude, effectiveRotX: effectiveRotX)

        case .peaked(let startTime, let direction, let peakAcceleration):
            handlePeakedState(now: now, startTime: startTime, direction: direction, peakAcceleration: peakAcceleration, effectiveRotX: effectiveRotX)
        }
    }

    private func handleIdleState(
        now: Date,
        acc: CMAcceleration,
        accMagnitude: Double,
        effectiveRotX: Double
    ) {
        // Använd gemensam trigger-funktion
        guard shouldStartGesture(acc: acc, effectiveRotX: effectiveRotX) else {
            return
        }

        // Kräv också tillräcklig total acceleration
        let sufficientAcceleration = accMagnitude > configuration.accelerationThreshold * 0.5
        guard sufficientAcceleration else {
            return
        }

        // Bestäm riktning baserat på rotation
        let direction: GestureDirection = effectiveRotX > 0 ? .forward : .backward

        gestureState = .initiated(startTime: now, direction: direction)
        maxAccelerationInGesture = accMagnitude

        log("State: idle → initiated(\(direction)) | rotX=\(String(format: "%.1f", effectiveRotX))°/s | acc(x=\(String(format: "%.2f", acc.x)), y=\(String(format: "%.2f", acc.y)), z=\(String(format: "%.2f", acc.z)))")
    }

    private func handleInitiatedState(
        now: Date,
        startTime: Date,
        direction: GestureDirection,
        accMagnitude: Double,
        effectiveRotX: Double
    ) {
        // Timeout-kontroll
        let elapsed = now.timeIntervalSince(startTime)
        if elapsed > configuration.gestureTimeout {
            log("Rejected: timeout in initiated state (\(String(format: "%.0f", elapsed * 1000))ms)")
            resetState()
            return
        }

        // Kontrollera att rotation fortsätter i rätt riktning
        let rotationConsistent = isRotationConsistent(effectiveRotX: effectiveRotX, direction: direction)
        if !rotationConsistent {
            log("Rejected: rotation direction changed in initiated state")
            resetState()
            return
        }

        // Uppdatera max acceleration
        if accMagnitude > maxAccelerationInGesture {
            maxAccelerationInGesture = accMagnitude
        }

        // Kontrollera om vi nått peak
        if isPeak(accMagnitude) && accMagnitude >= configuration.accelerationThreshold {
            gestureState = .peaked(startTime: startTime, direction: direction, peakAcceleration: accMagnitude)
            log("State: initiated → peaked | peak=\(String(format: "%.2f", accMagnitude))g")
        }
    }

    private func handlePeakedState(
        now: Date,
        startTime: Date,
        direction: GestureDirection,
        peakAcceleration: Double,
        effectiveRotX: Double
    ) {
        let elapsed = now.timeIntervalSince(startTime)

        // Timeout-kontroll (för lång)
        if elapsed > configuration.gestureTimeout {
            log("Rejected: timeout in peaked state (\(String(format: "%.0f", elapsed * 1000))ms)")
            resetState()
            return
        }

        // Minimum duration-kontroll (för kort = troligen inte en riktig gest)
        if elapsed < C.gestureMinDuration {
            // Vänta - gesten är inte klar ännu
            return
        }

        // Kontrollera rotation
        let rotationConfirmed = abs(effectiveRotX) >= configuration.rotationThreshold
        let rotationConsistent = isRotationConsistent(effectiveRotX: effectiveRotX, direction: direction)

        if !rotationConsistent {
            log("Rejected: rotation direction inconsistent in peaked state")
            resetState()
            return
        }

        if rotationConfirmed {
            // Gest bekräftad!
            completeGesture(direction: direction, peakAcceleration: peakAcceleration, rotX: effectiveRotX, elapsed: elapsed)
        }
    }

    private func completeGesture(
        direction: GestureDirection,
        peakAcceleration: Double,
        rotX: Double,
        elapsed: TimeInterval
    ) {
        let flickDirection: DetectedGesture.FlickDirection = direction == .forward ? .forward : .backward
        let gesture = DetectedGesture.flick(direction: flickDirection)

        lastGestureTime = Date()
        lastDetectedGesture = gesture
        onGestureDetected?(gesture)

        log("DETECTED: \(flickDirection) | peak=\(String(format: "%.2f", peakAcceleration))g | rotX=\(String(format: "%.1f", rotX))°/s | time=\(String(format: "%.0f", elapsed * 1000))ms")

        resetState()
    }

    // MARK: - Arm-Lift Filter

    /// Detekterar arm-lyft och andra icke-bladvänd-rörelser som ska ignoreras.
    ///
    /// Bladvänd-gest kräver:
    /// - X-acceleration dominerar (sidledrörelse)
    /// - rot.x dominerar (pronation/supination)
    ///
    /// Ignorera om:
    /// - Y eller Z dominerar (vertikal rörelse eller framåt/bakåt)
    /// - rot.z dominerar över rot.x (vridning utan bladvänd)
    private func isArmLift(acc: CMAcceleration, rot: CMRotationRate) -> Bool {
        let absX = abs(acc.x)
        let absY = abs(acc.y)
        let absZ = abs(acc.z)

        // Rotationer i grader/sekund
        let rotXDeg = abs(rot.x) * 180.0 / .pi
        let rotZDeg = abs(rot.z) * 180.0 / .pi

        // 1. Z-acceleration dominerar = rörelse framåt/bakåt från kroppen (typiskt arm-lyft)
        let zDominatesAccel = absZ > absX * 1.5 && absZ > 1.0
        if zDominatesAccel {
            return true
        }

        // 2. Y-acceleration dominerar och X är låg = ren vertikal rörelse
        let yDominatesOverX = absY > absX * C.armLiftYMultiplier
        let lowXAcceleration = absX < C.armLiftMinX
        if yDominatesOverX && lowXAcceleration {
            return true
        }

        // 3. rot.z dominerar kraftigt över rot.x = vridning utan pronation/supination
        //    (ren sidledssvepning utan bladvänd-rotation)
        let zRotationDominates = rotZDeg > rotXDeg * 3.0 && rotZDeg > 100.0
        if zRotationDominates {
            return true
        }

        return false
    }

    // MARK: - Helper Methods

    private func isRotationConsistent(effectiveRotX: Double, direction: GestureDirection) -> Bool {
        // Rotation måste vara i samma riktning som initierad
        // Tillåt lite slack för brus
        let minRotation: Double = 5.0  // grader/sekund

        switch direction {
        case .forward:
            return effectiveRotX > -minRotation  // Ska vara positiv eller nära noll
        case .backward:
            return effectiveRotX < minRotation   // Ska vara negativ eller nära noll
        }
    }

    private func updateAccelerationWindow(_ magnitude: Double) {
        recentAccelerations.append(magnitude)
        if recentAccelerations.count > peakWindowSize {
            recentAccelerations.removeFirst()
        }
    }

    private func isPeak(_ value: Double) -> Bool {
        guard recentAccelerations.count >= 3 else { return false }
        let lastIndex = recentAccelerations.count - 1

        // Värdet är en peak om det är större eller lika med de två föregående
        return value >= recentAccelerations[lastIndex - 1] &&
               value >= recentAccelerations[lastIndex - 2]
    }

    private func resetState() {
        gestureState = .idle
        maxAccelerationInGesture = 0
        recentAccelerations.removeAll()
        resetDTWState()
    }

    private func log(_ message: String) {
        print("[GestureDetector] \(message)")
    }
}

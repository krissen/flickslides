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
        static let rotationThreshold = "rotationThreshold"  // Legacy
        static let rotationThresholdForward = "rotationThresholdForward"
        static let rotationThresholdBackward = "rotationThresholdBackward"
        static let gestureDebounceInterval = "gestureDebounceInterval"
        static let watchOnRightWrist = "watchOnRightWrist"
    }

    // MARK: - State Machine

    private enum GestureState: CustomStringConvertible {
        case idle
        case initiated(startTime: Date, direction: GestureDirection)
        case peaked(startTime: Date, direction: GestureDirection, peakAcceleration: Double)
        /// Landing-fas: väntar på att rörelsen ska "landa" (acceleration och rotation avtar)
        case landing(startTime: Date, direction: GestureDirection, peakAcceleration: Double, peakTime: Date)

        var description: String {
            switch self {
            case .idle:
                return "idle"
            case .initiated(_, let direction):
                return "initiated(\(direction))"
            case .peaked(_, let direction, let peak):
                return "peaked(\(direction), peak=\(String(format: "%.2f", peak))g)"
            case .landing(_, let direction, let peak, _):
                return "landing(\(direction), peak=\(String(format: "%.2f", peak))g)"
            }
        }
    }

    fileprivate enum GestureDirection {
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

        /// Minimum rotation för FRAMÅT/NEXT - pronation (grader/sekund)
        var rotationThresholdForward: Double

        /// Minimum rotation för BAKÅT/PREV - supination (grader/sekund)
        var rotationThresholdBackward: Double

        /// Cooldown mellan gester (sekunder)
        var debounceInterval: TimeInterval

        /// Sampling-frekvens (Hz)
        var samplingRate: Double

        /// Klockan sitter på höger handled (påverkar rotationsriktning)
        var watchOnRightWrist: Bool

        /// Max tid för en gest från initiation till completion (sekunder)
        var gestureTimeout: TimeInterval

        /// Legacy: returnerar forward-tröskeln för bakåtkompatibilitet
        var rotationThreshold: Double { rotationThresholdForward }

        /// Returnerar rätt rotationströskel baserat på riktning (privat pga GestureDirection)
        fileprivate func rotationThreshold(for direction: GestureDirection) -> Double {
            switch direction {
            case .forward: return rotationThresholdForward
            case .backward: return rotationThresholdBackward
            }
        }

        /// Skapar konfiguration med värden från UserDefaults (med app group för delning med iPhone)
        static func fromUserDefaults() -> Configuration {
            let defaults = UserDefaults(suiteName: "group.com.kristianniemi.FlickSlides") ?? .standard

            let accelThreshold = defaults.object(forKey: UserDefaultsKeys.accelerationThreshold) as? Double
                ?? C.accelerationThreshold

            // Nya separata rotationströsklar
            let rotForward = defaults.object(forKey: UserDefaultsKeys.rotationThresholdForward) as? Double
                ?? C.rotationThresholdForward
            let rotBackward = defaults.object(forKey: UserDefaultsKeys.rotationThresholdBackward) as? Double
                ?? C.rotationThresholdBackward

            let debounce = defaults.object(forKey: UserDefaultsKeys.gestureDebounceInterval) as? Double
                ?? C.gestureDebounceInterval
            let rightWrist = defaults.object(forKey: UserDefaultsKeys.watchOnRightWrist) as? Bool ?? true

            return Configuration(
                accelerationThreshold: accelThreshold,
                rotationThresholdForward: rotForward,
                rotationThresholdBackward: rotBackward,
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

    // Kumulativ rotation för att verifiera att handleden faktiskt vrids
    private var cumulativeRotation: Double = 0
    private var lastSampleTime: Date?

    // Landing-detektion för DTW
    private var dtwPeakAcceleration: Double = 0
    private var dtwPeakTime: Date?
    private var dtwHasReachedPeak: Bool = false

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
        log("Configuration reloaded: accel=\(configuration.accelerationThreshold)g, rotFwd=\(configuration.rotationThresholdForward)°/s, rotBwd=\(configuration.rotationThresholdBackward)°/s, debounce=\(configuration.debounceInterval)s, wrist=\(configuration.watchOnRightWrist ? "right" : "left")")
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
            processDTWStrategy(now: now, accMagnitude: accMagnitude, rotationRate: currentRotationRate)
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

    /// Kontrollerar om rotation är isolerad till X-axeln (pronation/supination).
    /// En äkta bladvänd-gest har handledsrotation, inte multiaxiell armrörelse.
    private func isRotationIsolated(rot: CMRotationRate) -> Bool {
        let rotXAbs = abs(rot.x) * 180.0 / .pi
        let rotYAbs = abs(rot.y) * 180.0 / .pi
        let rotZAbs = abs(rot.z) * 180.0 / .pi
        let totalRotation = rotXAbs + rotYAbs + rotZAbs

        guard totalRotation > 10.0 else { return false }  // Minst 10°/s total

        let xDominance = rotXAbs / totalRotation
        return xDominance >= C.rotationIsolationThreshold
    }

    /// Avgör om en gest ska initieras baserat på sensordata.
    /// Används av BÅDE DTW och tröskelbaserad strategi för konsekvent beteende.
    ///
    /// Krav för att starta gest:
    /// - X-acceleration dominerar (sidledrörelse)
    /// - X-acceleration > 0.5g
    /// - Rotation i pronation/supination-axeln > initiationRotationThreshold
    /// - Rotation är isolerad till X-axeln (dominans > rotationIsolationThreshold)
    private func shouldStartGesture(acc: CMAcceleration, rot: CMRotationRate, effectiveRotX: Double) -> Bool {
        let absX = abs(acc.x)
        let absY = abs(acc.y)
        let absZ = abs(acc.z)

        // X måste vara den dominanta axeln för en riktig bladvänd-gest
        let xIsLargest = absX >= absY && absX >= absZ
        let xIsSignificant = absX > 0.5  // Minst 0.5g i sidled

        guard xIsLargest && xIsSignificant else {
            return false
        }

        // Rotation måste ha påbörjats med tillräcklig styrka
        let rotationStarted = abs(effectiveRotX) > C.initiationRotationThreshold
        guard rotationStarted else {
            return false
        }

        // NY: Rotation måste vara isolerad till X-axeln (pronation/supination)
        // Detta filtrerar bort multiaxiella rörelser som gestikulerande
        guard isRotationIsolated(rot: rot) else {
            logDiagnostic("Rejected start: rotation not isolated (rotX=\(String(format: "%.1f", abs(effectiveRotX)))°/s)")
            return false
        }

        return true
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
        if dtwGestureStartTime == nil && shouldStartGesture(acc: acc, rot: rot, effectiveRotX: effectiveRotX) {
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
        // Reset landing-detektion
        dtwPeakAcceleration = 0
        dtwPeakTime = nil
        dtwHasReachedPeak = false
    }

    // MARK: - DTW Strategy

    /// Processar DTW-strategin med landing-detektion.
    ///
    /// Landing-kriterier (alla måste uppfyllas):
    /// 1. Acceleration har nått peak och sjunkit minst 50%
    /// 2. Rotation har saktat ner (< 30°/s)
    /// 3. Minst 150ms har passerat sedan peak
    /// 4. DTW-match confidence >= threshold
    private func processDTWStrategy(now: Date, accMagnitude: Double, rotationRate: Double) {
        guard let startTime = dtwGestureStartTime else { return }

        let elapsed = now.timeIntervalSince(startTime)

        // Timeout - avbryt om gesten tar för lång tid
        if elapsed > 1.5 {
            log("DTW: timeout after \(String(format: "%.0f", elapsed * 1000))ms")
            resetDTWState()
            return
        }

        // Tracka peak acceleration
        if accMagnitude > dtwPeakAcceleration {
            dtwPeakAcceleration = accMagnitude
            dtwPeakTime = now
            dtwHasReachedPeak = false
        }

        // Detektera peak (acceleration har börjat sjunka)
        if !dtwHasReachedPeak && dtwPeakAcceleration > 0.5 {
            let dropFromPeak = dtwPeakAcceleration - accMagnitude
            if dropFromPeak > dtwPeakAcceleration * 0.3 {
                // Acceleration har sjunkit 30% från peak - vi har passerat peak
                dtwHasReachedPeak = true
                log("DTW: peak detected at \(String(format: "%.2f", dtwPeakAcceleration))g")
            }
        }

        // Landing-kriterier
        guard dtwHasReachedPeak, let peakTime = dtwPeakTime else {
            return  // Vänta på peak
        }

        let timeSincePeak = now.timeIntervalSince(peakTime)
        let accelerationSettled = accMagnitude < dtwPeakAcceleration * 0.5
        let rotationSettled = rotationRate < 30.0
        let enoughTimeAfterPeak = timeSincePeak >= 0.15

        // Alla landing-kriterier uppfyllda?
        let landingConfirmed = accelerationSettled && rotationSettled && enoughTimeAfterPeak

        // Minst 200ms total tid för att undvika för korta gester
        let minimumElapsed = elapsed >= 0.2

        guard landingConfirmed && minimumElapsed else {
            // Logga väntan (rate-limited)
            if timeSincePeak > 0.1 {
                logDiagnostic("DTW waiting: accSettled=\(accelerationSettled) rotSettled=\(rotationSettled) timeOK=\(enoughTimeAfterPeak)")
            }
            return
        }

        // Landing bekräftad - försök matcha
        if let gesture = tryDTWMatch() {
            lastGestureTime = now
            lastDetectedGesture = gesture
            onGestureDetected?(gesture)
            log("DETECTED (DTW): \(gesture) | peak=\(String(format: "%.2f", dtwPeakAcceleration))g | time=\(String(format: "%.0f", elapsed * 1000))ms | samples=\(dtwSamples.count)")
        } else {
            log("DTW: no match after landing, samples=\(dtwSamples.count), peak=\(String(format: "%.2f", dtwPeakAcceleration))g")
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
            handleIdleState(now: now, acc: acc, rot: rot, accMagnitude: accMagnitude, effectiveRotX: effectiveRotX)

        case .initiated(let startTime, let direction):
            handleInitiatedState(now: now, startTime: startTime, direction: direction, rot: rot, accMagnitude: accMagnitude, effectiveRotX: effectiveRotX)

        case .peaked(let startTime, let direction, let peakAcceleration):
            handlePeakedState(now: now, startTime: startTime, direction: direction, rot: rot, accMagnitude: accMagnitude, peakAcceleration: peakAcceleration, effectiveRotX: effectiveRotX)

        case .landing(let startTime, let direction, let peakAcceleration, let peakTime):
            handleLandingState(now: now, startTime: startTime, direction: direction, peakAcceleration: peakAcceleration, peakTime: peakTime, accMagnitude: accMagnitude, rotationRate: currentRotationRate, effectiveRotX: effectiveRotX)
        }
    }

    private func handleIdleState(
        now: Date,
        acc: CMAcceleration,
        rot: CMRotationRate,
        accMagnitude: Double,
        effectiveRotX: Double
    ) {
        // Använd gemensam trigger-funktion (inkl. rotationsisolering)
        guard shouldStartGesture(acc: acc, rot: rot, effectiveRotX: effectiveRotX) else {
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

        // Starta kumulativ rotationsmätning
        cumulativeRotation = 0
        lastSampleTime = now

        log("State: idle → initiated(\(direction)) | rotX=\(String(format: "%.1f", effectiveRotX))°/s | acc(x=\(String(format: "%.2f", acc.x)), y=\(String(format: "%.2f", acc.y)), z=\(String(format: "%.2f", acc.z)))")
    }

    private func handleInitiatedState(
        now: Date,
        startTime: Date,
        direction: GestureDirection,
        rot: CMRotationRate,
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

        // Uppdatera kumulativ rotation
        if let lastTime = lastSampleTime {
            let dt = now.timeIntervalSince(lastTime)
            cumulativeRotation += abs(effectiveRotX) * dt
        }
        lastSampleTime = now

        // Uppdatera max acceleration
        if accMagnitude > maxAccelerationInGesture {
            maxAccelerationInGesture = accMagnitude
        }

        // Kontrollera om vi nått peak
        if isPeak(accMagnitude) && accMagnitude >= configuration.accelerationThreshold {
            gestureState = .peaked(startTime: startTime, direction: direction, peakAcceleration: accMagnitude)
            log("State: initiated → peaked | peak=\(String(format: "%.2f", accMagnitude))g | cumRot=\(String(format: "%.1f", cumulativeRotation))°")
        }
    }

    private func handlePeakedState(
        now: Date,
        startTime: Date,
        direction: GestureDirection,
        rot: CMRotationRate,
        accMagnitude: Double,
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

        // Uppdatera kumulativ rotation
        if let lastTime = lastSampleTime {
            let dt = now.timeIntervalSince(lastTime)
            cumulativeRotation += abs(effectiveRotX) * dt
        }
        lastSampleTime = now

        // Uppdatera peak om acceleration fortfarande ökar
        var currentPeak = peakAcceleration
        if accMagnitude > peakAcceleration {
            currentPeak = accMagnitude
            gestureState = .peaked(startTime: startTime, direction: direction, peakAcceleration: currentPeak)
        }

        // Minimum duration-kontroll (för kort = troligen inte en riktig gest)
        if elapsed < C.gestureMinDuration {
            return
        }

        // Kontrollera rotation med riktningsspecifik tröskel
        let requiredRotation = configuration.rotationThreshold(for: direction)
        let rotationConfirmed = abs(effectiveRotX) >= requiredRotation
        let rotationConsistent = isRotationConsistent(effectiveRotX: effectiveRotX, direction: direction)

        if !rotationConsistent {
            log("Rejected: rotation direction inconsistent in peaked state")
            resetState()
            return
        }

        // Kontrollera kumulativ rotation
        if cumulativeRotation < C.minimumCumulativeRotation {
            // Vänta på mer rotation
            return
        }

        // När rotation bekräftats, gå till landing-fas för att vänta på att rörelsen "landar"
        if rotationConfirmed {
            gestureState = .landing(startTime: startTime, direction: direction, peakAcceleration: currentPeak, peakTime: now)
            log("State: peaked → landing | peak=\(String(format: "%.2f", currentPeak))g | cumRot=\(String(format: "%.1f", cumulativeRotation))°")
        }
    }

    /// Hanterar landing-fasen: väntar på att acceleration och rotation avtar.
    private func handleLandingState(
        now: Date,
        startTime: Date,
        direction: GestureDirection,
        peakAcceleration: Double,
        peakTime: Date,
        accMagnitude: Double,
        rotationRate: Double,
        effectiveRotX: Double
    ) {
        let elapsed = now.timeIntervalSince(startTime)
        let timeSincePeak = now.timeIntervalSince(peakTime)

        // Timeout - men ge mer tid för landing
        if elapsed > configuration.gestureTimeout + 0.3 {
            log("Rejected: timeout in landing state (\(String(format: "%.0f", elapsed * 1000))ms)")
            resetState()
            return
        }

        // Landing-kriterier:
        // 1. Acceleration har sjunkit minst 50% från peak
        let accelerationSettled = accMagnitude < peakAcceleration * 0.5

        // 2. Rotation har saktat ner (< 40°/s magnitude)
        let rotationSettled = rotationRate < 40.0

        // 3. Minst 100ms har passerat sedan peak
        let enoughTimeAfterPeak = timeSincePeak >= 0.1

        // Alla landing-kriterier uppfyllda?
        if accelerationSettled && rotationSettled && enoughTimeAfterPeak {
            // Kontrollera att rotation fortfarande är i rätt riktning (inte helt vänt)
            let rotationConsistent = isRotationConsistent(effectiveRotX: effectiveRotX, direction: direction)
            if !rotationConsistent && abs(effectiveRotX) > 20.0 {
                log("Rejected: rotation reversed during landing")
                resetState()
                return
            }

            // Gest bekräftad efter landing!
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
            logDiagnostic("Filtered: Z-accel dominates (z=\(String(format: "%.2f", absZ)), x=\(String(format: "%.2f", absX)))")
            return true
        }

        // 2. Y-acceleration dominerar och X är låg = ren vertikal rörelse
        let yDominatesOverX = absY > absX * C.armLiftYMultiplier
        let lowXAcceleration = absX < C.armLiftMinX
        if yDominatesOverX && lowXAcceleration {
            logDiagnostic("Filtered: Y dominates, low X (y=\(String(format: "%.2f", absY)), x=\(String(format: "%.2f", absX)))")
            return true
        }

        // 3. rot.z dominerar kraftigt över rot.x = vridning utan pronation/supination
        //    (ren sidledssvepning utan bladvänd-rotation)
        let zRotationDominates = rotZDeg > rotXDeg * 3.0 && rotZDeg > 100.0
        if zRotationDominates {
            logDiagnostic("Filtered: rotZ dominates (rotZ=\(String(format: "%.1f", rotZDeg))°/s, rotX=\(String(format: "%.1f", rotXDeg))°/s)")
            return true
        }

        return false
    }

    /// Diagnostiklogg för avvisade gester (endast för felsökning)
    private var diagnosticLoggingEnabled = false
    private var lastDiagnosticLog = Date.distantPast

    private func logDiagnostic(_ message: String) {
        guard diagnosticLoggingEnabled else { return }
        // Rate-limit diagnostiklogg till max 1 per sekund
        let now = Date()
        guard now.timeIntervalSince(lastDiagnosticLog) > 1.0 else { return }
        lastDiagnosticLog = now
        print("[GestureDetector:DIAG] \(message)")
    }

    /// Aktiverar/avaktiverar detaljerad diagnostikloggning
    func setDiagnosticLogging(_ enabled: Bool) {
        diagnosticLoggingEnabled = enabled
        log("Diagnostic logging \(enabled ? "enabled" : "disabled")")
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
        cumulativeRotation = 0
        lastSampleTime = nil
        resetDTWState()
    }

    private func log(_ message: String) {
        print("[GestureDetector] \(message)")
    }
}

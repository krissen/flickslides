import Foundation
import CoreMotion

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

    // MARK: - Constants

    private enum Defaults {
        static let accelerationThreshold: Double = 1.5      // g - minimum acceleration
        static let rotationThreshold: Double = 30.0         // grader/sekund
        static let gestureDebounceInterval: Double = 1.0    // sekunder
        static let samplingRate: Double = 50.0              // Hz
        static let gestureTimeout: Double = 0.6             // sekunder - max tid för en gest
        static let gestureMinDuration: Double = 0.08        // sekunder - minimum tid för en gest (80ms)
        static let armLiftYMultiplier: Double = 1.5         // Y > X * multiplier = arm-lyft
        static let armLiftMinX: Double = 0.5                // g - minimum X för att inte vara arm-lyft
        static let initiationRotationThreshold: Double = 10.0  // grader/sekund - start av rotation
        static let peakAccelerationRatio: Double = 0.8      // peak måste vara minst 80% av max
    }

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
                ?? Defaults.accelerationThreshold
            let rotThreshold = defaults.object(forKey: UserDefaultsKeys.rotationThreshold) as? Double
                ?? Defaults.rotationThreshold
            let debounce = defaults.object(forKey: UserDefaultsKeys.gestureDebounceInterval) as? Double
                ?? Defaults.gestureDebounceInterval
            let rightWrist = defaults.object(forKey: UserDefaultsKeys.watchOnRightWrist) as? Bool ?? true

            return Configuration(
                accelerationThreshold: accelThreshold,
                rotationThreshold: rotThreshold,
                debounceInterval: debounce,
                samplingRate: Defaults.samplingRate,
                watchOnRightWrist: rightWrist,
                gestureTimeout: Defaults.gestureTimeout
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

    // Auto-reload configuration
    private var lastConfigReload: Date = .distantPast
    private let configReloadInterval: TimeInterval = 3.0  // Ladda om var 3:e sekund

    // MARK: - Initialization

    init() {
        self.configuration = Configuration.fromUserDefaults()
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
        log("Started with \(configuration.samplingRate) Hz, wrist=\(configuration.watchOnRightWrist ? "right" : "left")")
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
        configuration = Configuration.fromUserDefaults()
        log("Configuration reloaded: accel=\(configuration.accelerationThreshold)g, rot=\(configuration.rotationThreshold)°/s, debounce=\(configuration.debounceInterval)s, wrist=\(configuration.watchOnRightWrist ? "right" : "left")")
    }

    // MARK: - Motion Processing

    private func processMotion(_ motion: CMDeviceMotion) {
        let now = Date()

        // Auto-reload konfiguration var 3:e sekund
        if now.timeIntervalSince(lastConfigReload) > configReloadInterval {
            let oldWrist = configuration.watchOnRightWrist
            configuration = Configuration.fromUserDefaults()
            lastConfigReload = now

            if oldWrist != configuration.watchOnRightWrist {
                log("Config auto-reloaded: wrist changed to \(configuration.watchOnRightWrist ? "right" : "left")")
            }
        }

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

        // Filtrera arm-lyft
        if isArmLift(acc: acc, rot: rot) {
            if case .idle = gestureState {
                // Tyst filtrering i idle
            } else {
                log("Rejected: arm-lift detected, resetting state")
                resetState()
            }
            return
        }

        // State machine processing
        processStateMachine(
            now: now,
            acc: acc,
            accMagnitude: accMagnitude,
            effectiveRotX: effectiveRotX
        )
    }

    // MARK: - State Machine

    private func processStateMachine(
        now: Date,
        acc: CMAcceleration,
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
        // Krav för initiation:
        // 1. X-acceleration dominerar (sidledrörelse, inte arm-lyft)
        // 2. Rotation påbörjad i rätt axel
        // 3. Acceleration över minimum

        let absX = abs(acc.x)
        let absY = abs(acc.y)
        let absZ = abs(acc.z)

        // X måste vara den dominanta axeln för en riktig bladvänd-gest
        // Arm-lyft har ofta Y eller Z dominant
        let xIsLargest = absX >= absY && absX >= absZ
        let xIsSignificant = absX > 0.5  // Minst 0.5g i sidled

        guard xIsLargest && xIsSignificant else {
            return
        }

        let rotationStarted = abs(effectiveRotX) > Defaults.initiationRotationThreshold
        let sufficientAcceleration = accMagnitude > configuration.accelerationThreshold * 0.5

        guard rotationStarted && sufficientAcceleration else {
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
        if elapsed < Defaults.gestureMinDuration {
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
        let yDominatesOverX = absY > absX * Defaults.armLiftYMultiplier
        let lowXAcceleration = absX < Defaults.armLiftMinX
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
    }

    private func log(_ message: String) {
        print("[GestureDetector] \(message)")
    }
}

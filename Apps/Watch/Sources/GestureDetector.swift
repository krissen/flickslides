import Foundation
import CoreMotion

/// Gestigenkänning baserad på accelerometer/gyroskop-data.
/// Kräver att BÅDE acceleration OCH rotation överskrider tröskelvärden för gestdetektering.
@MainActor
final class GestureDetector: ObservableObject {

    // MARK: - Constants

    private enum Defaults {
        static let accelerationThreshold: Double = 1.5
        static let rotationThreshold: Double = 30.0  // grader/sekund
        static let gestureDebounceInterval: Double = 1.5
        static let samplingRate: Double = 50.0
    }

    private enum UserDefaultsKeys {
        static let accelerationThreshold = "accelerationThreshold"
        static let rotationThreshold = "rotationThreshold"
        static let gestureDebounceInterval = "gestureDebounceInterval"
        static let watchOnRightWrist = "watchOnRightWrist"
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
                watchOnRightWrist: rightWrist
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
    private var recentAccelerations: [Double] = []
    private var recentRotations: [Double] = []
    private let peakWindowSize = 10

    // MARK: - Initialization

    init() {
        self.configuration = Configuration.fromUserDefaults()
    }

    // MARK: - Public Methods

    func start(onGesture: @escaping (DetectedGesture) -> Void) {
        guard motionManager.isDeviceMotionAvailable else {
            print("[GestureDetector] Device motion not available")
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
        print("[GestureDetector] Started with \(configuration.samplingRate) Hz")
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        isActive = false
        onGestureDetected = nil
        recentAccelerations.removeAll()
        recentRotations.removeAll()
        print("[GestureDetector] Stopped")
    }

    /// Laddar om konfiguration från UserDefaults (anropas t.ex. vid app-aktivering)
    func reloadConfiguration() {
        configuration = Configuration.fromUserDefaults()
        print("[GestureDetector] Configuration reloaded: accel=\(configuration.accelerationThreshold)g, rot=\(configuration.rotationThreshold)°/s, debounce=\(configuration.debounceInterval)s")
    }

    // MARK: - Motion Processing

    private func processMotion(_ motion: CMDeviceMotion) {
        // Läs acceleration
        let acc = motion.userAcceleration
        let accMagnitude = sqrt(acc.x * acc.x + acc.y * acc.y + acc.z * acc.z)
        currentAcceleration = accMagnitude

        // Läs rotation rate (radianer/sekund → grader/sekund)
        let rot = motion.rotationRate
        let rotMagnitudeRad = sqrt(rot.x * rot.x + rot.y * rot.y + rot.z * rot.z)
        let rotMagnitudeDeg = rotMagnitudeRad * 180.0 / .pi
        currentRotationRate = rotMagnitudeDeg

        // Rotation Z i grader/sekund (för riktningsbestämning)
        let rotZDeg = rot.z * 180.0 / .pi

        // Håll koll på senaste värden för peak-detection
        recentAccelerations.append(accMagnitude)
        if recentAccelerations.count > peakWindowSize {
            recentAccelerations.removeFirst()
        }

        recentRotations.append(rotMagnitudeDeg)
        if recentRotations.count > peakWindowSize {
            recentRotations.removeFirst()
        }

        // Kolla debounce
        let now = Date()
        guard now.timeIntervalSince(lastGestureTime) > configuration.debounceInterval else {
            return
        }

        // Filtrera bort vertikala rörelser (lyft/sänk arm)
        // Om Y-acceleration dominerar är det troligen inte en "flick"
        let dominated = max(abs(acc.x), abs(acc.y), abs(acc.z))
        let isVerticalMovement = abs(acc.y) == dominated && abs(acc.y) > 0.8

        if isVerticalMovement {
            return  // Ignorera vertikala rörelser
        }

        // Detektera gest: kräv BÅDE acceleration OCH rotation över respektive tröskelvärde
        let accelerationOK = accMagnitude > configuration.accelerationThreshold
        let rotationOK = rotMagnitudeDeg > configuration.rotationThreshold

        if accelerationOK && rotationOK && isPeak(accMagnitude) {
            let direction = determineDirection(rotZ: rotZDeg)
            let gesture = DetectedGesture.flick(direction: direction)

            lastGestureTime = now
            lastDetectedGesture = gesture
            onGestureDetected?(gesture)

            print("[GestureDetector] Detected: \(gesture) | accel=\(String(format: "%.2f", accMagnitude))g | rot=\(String(format: "%.1f", rotMagnitudeDeg))°/s | rotZ=\(String(format: "%.1f", rotZDeg))°/s | acc(x=\(String(format: "%.2f", acc.x)), y=\(String(format: "%.2f", acc.y)), z=\(String(format: "%.2f", acc.z)))")
        }
    }

    private func isPeak(_ value: Double) -> Bool {
        guard recentAccelerations.count >= 3 else { return false }
        let lastIndex = recentAccelerations.count - 1
        return value >= recentAccelerations[lastIndex - 1] &&
               value >= recentAccelerations[lastIndex - 2]
    }

    /// Bestäm riktning baserat på rotation Z-axeln (handledsvridning)
    /// Rotationsriktningen inverteras beroende på vilken handled klockan sitter på.
    private func determineDirection(rotZ: Double) -> DetectedGesture.FlickDirection {
        // "Bladvänd höger" (NEXT): hand roterar inåt
        // "Bladvänd vänster" (PREV): hand roterar utåt
        // På höger handled är rotationsriktningen inverterad jämfört med vänster
        let effectiveRotZ = configuration.watchOnRightWrist ? -rotZ : rotZ
        return effectiveRotZ < 0 ? .forward : .backward
    }
}

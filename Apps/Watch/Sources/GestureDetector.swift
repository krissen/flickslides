import Foundation
import CoreMotion

/// Gestigenkänning baserad på accelerometer/gyroskop-data.
@MainActor
final class GestureDetector: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isActive = false
    @Published private(set) var lastDetectedGesture: DetectedGesture?
    @Published private(set) var currentAcceleration: Double = 0

    // MARK: - Configuration

    struct Configuration {
        /// Minimum acceleration för att räknas som gest (g)
        var accelerationThreshold: Double = 0.8

        /// Minimum rotation för handflick (grader)
        var rotationThreshold: Double = 18.0

        /// Cooldown mellan gester (sekunder)
        var debounceInterval: TimeInterval = 1.0

        /// Sampling-frekvens (Hz)
        var samplingRate: Double = 50.0
    }

    var configuration = Configuration()

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
    private let peakWindowSize = 10

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
        print("[GestureDetector] Stopped")
    }

    // MARK: - Motion Processing

    private func processMotion(_ motion: CMDeviceMotion) {
        let acc = motion.userAcceleration
        let magnitude = sqrt(acc.x * acc.x + acc.y * acc.y + acc.z * acc.z)
        currentAcceleration = magnitude

        // Håll koll på senaste värden för peak-detection
        recentAccelerations.append(magnitude)
        if recentAccelerations.count > peakWindowSize {
            recentAccelerations.removeFirst()
        }

        // Kolla debounce
        let now = Date()
        guard now.timeIntervalSince(lastGestureTime) > configuration.debounceInterval else {
            return
        }

        // Detektera gest om acceleration överstiger tröskel och är en peak
        if magnitude > configuration.accelerationThreshold && isPeak(magnitude) {
            let direction = determineDirection(acc)
            let gesture = DetectedGesture.flick(direction: direction)

            lastGestureTime = now
            lastDetectedGesture = gesture
            onGestureDetected?(gesture)

            print("[GestureDetector] Detected: \(gesture) at \(magnitude)g")
        }
    }

    private func isPeak(_ value: Double) -> Bool {
        guard recentAccelerations.count >= 3 else { return false }
        let lastIndex = recentAccelerations.count - 1
        return value >= recentAccelerations[lastIndex - 1] &&
               value >= recentAccelerations[lastIndex - 2]
    }

    /// Bestäm riktning baserat på X-axelns accelerationsaxel
    private func determineDirection(_ acc: CMAcceleration) -> DetectedGesture.FlickDirection {
        // X-axeln är typiskt framåt/bakåt när armen är i presentationsställning
        // Positiv X = framåt (nästa), Negativ X = bakåt (föregående)
        return acc.x > 0 ? .forward : .backward
    }
}

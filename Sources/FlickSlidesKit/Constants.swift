import Foundation

/// Konstanter för FlickSlides.
public enum FlickSlidesConstants {

    // MARK: - Service Identifiers

    /// Service-typ för MultipeerConnectivity (max 15 tecken, lowercase + hyphen)
    public static let multipeerServiceType = "flickslides-ctl"  // 15 tecken exakt

    /// Bonjour service-typ (alternativ)
    public static let bonjourServiceType = "_flickslides._tcp"

    // MARK: - Gesture Detection Thresholds

    /// Minimum acceleration för att räknas som gest (g)
    /// Höjd från 1.0 för att filtrera gångrörelser (typiskt 0.8-1.2g)
    public static let accelerationThreshold: Double = 1.3

    /// Minimum rotation för handflick (grader/sekund) - legacy, använd direction-specifika
    public static let rotationThreshold: Double = 120.0

    /// Rotation för FRAMÅT/NEXT (pronation) - kräver tydlig handledsrotation
    /// Höjd från 60 för att kräva en medveten gest
    public static let rotationThresholdForward: Double = 120.0

    /// Rotation för BAKÅT/PREV (supination) - kräver tydlig handledsrotation
    /// Höjd från 30 för att undvika false positives vid naturliga rörelser
    public static let rotationThresholdBackward: Double = 80.0

    /// Debounce-intervall mellan gester (sekunder)
    public static let gestureDebounceInterval: TimeInterval = 1.0

    /// Max tid för en gest från initiation till completion (sekunder)
    public static let gestureTimeout: TimeInterval = 0.4

    /// Minimum tid för en gest (sekunder) - för kort = troligen inte riktig gest
    /// Höjd från 0.08 för att filtrera korta brusrörelser
    public static let gestureMinDuration: TimeInterval = 0.12

    /// Rotation som krävs för att starta en gest (grader/sekund)
    /// Höjd från 10 för att kräva tydlig rotationsstart
    public static let initiationRotationThreshold: Double = 40.0

    /// Minimum kumulativ rotation under hela gesten (grader)
    /// Kräver att handleden faktiskt vrids, inte bara snabbt rör sig
    public static let minimumCumulativeRotation: Double = 15.0

    /// Minimum rot.x-dominans för att räknas som bladvänd-gest (0-1)
    /// rot.x / (|rot.x| + |rot.y| + |rot.z|) måste överstiga detta
    /// Sänkt från 0.5 till 0.35 - 0.5 var för strikt och avvisade alla gester
    public static let rotationIsolationThreshold: Double = 0.35

    // MARK: - Arm-Lift Filter

    /// Y > X * multiplier = arm-lyft (ignoreras)
    public static let armLiftYMultiplier: Double = 1.5

    /// Minimum X-acceleration för att inte vara arm-lyft (g)
    public static let armLiftMinX: Double = 0.5

    // MARK: - Calibration Thresholds

    /// Lägre accelerationströskel för kalibrering (g) - mjukare gester accepteras
    public static let calibrationAccelerationThreshold: Double = 0.6

    /// Acceleration som räknas som "vilande" vid kalibrering (g)
    public static let calibrationIdleThreshold: Double = 0.15

    /// Tid av stillhet som krävs för att räknas som "vilande" (sekunder)
    public static let calibrationIdleRequiredDuration: TimeInterval = 0.3

    /// Minimum antal samples för giltig kalibrerings-gest
    public static let calibrationMinSamples: Int = 15

    /// Max inspelningstid för kalibrering (sekunder)
    public static let calibrationMaxDuration: TimeInterval = 2.0

    /// Min inspelningstid för kalibrering (sekunder)
    public static let calibrationMinDuration: TimeInterval = 0.3

    /// Acceleration som avslutar kalibrerings-inspelning (g)
    public static let calibrationEndThreshold: Double = 0.2

    /// Timeout om ingen gest detekteras vid kalibrering (sekunder)
    public static let calibrationRecordingTimeout: TimeInterval = 10.0

    // MARK: - DTW (Dynamic Time Warping)

    /// Tröskel för DTW-avstånd (normaliserat)
    public static let dtwDistanceThreshold: Double = 0.5

    /// Minimum confidence för DTW-matchning
    public static let dtwConfidenceThreshold: Double = 0.6

    /// Antal samples i pre-buffer för att fånga geststart
    public static let dtwPreBufferSize: Int = 10

    // MARK: - Sensor Configuration

    /// Sampling-frekvens för sensorer (Hz)
    public static let sensorSamplingRate: Double = 50.0

    // MARK: - Latency & Performance

    /// Maximal latens som är acceptabel (ms)
    public static let maxAcceptableLatencyMs: Int = 500

    /// Anti-spam cooldown på Mac (sekunder)
    public static let macCommandCooldown: TimeInterval = 0.5
}

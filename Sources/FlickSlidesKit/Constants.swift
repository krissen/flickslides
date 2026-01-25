import Foundation

/// Konstanter för FlickSlides.
public enum FlickSlidesConstants {
    /// Service-typ för MultipeerConnectivity (max 15 tecken, lowercase + hyphen)
    public static let multipeerServiceType = "flickslides-ctl"  // 15 tecken exakt

    /// Bonjour service-typ (alternativ)
    public static let bonjourServiceType = "_flickslides._tcp"

    /// Debounce-intervall mellan gester (sekunder)
    public static let gestureDebounceInterval: TimeInterval = 1.5

    /// Minimum acceleration för att räknas som gest (g)
    public static let accelerationThreshold: Double = 1.5

    /// Minimum rotation för handflick (grader)
    public static let rotationThreshold: Double = 18.0

    /// Sampling-frekvens för sensorer (Hz)
    public static let sensorSamplingRate: Double = 50.0

    /// Maximal latens som är acceptabel (ms)
    public static let maxAcceptableLatencyMs: Int = 500

    /// Anti-spam cooldown på Mac (sekunder)
    public static let macCommandCooldown: TimeInterval = 0.5
}

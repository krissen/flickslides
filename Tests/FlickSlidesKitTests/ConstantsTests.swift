import Foundation
import Testing
@testable import FlickSlidesKit

@Suite("FlickSlidesConstants")
struct ConstantsTests {

    // MARK: - Service Identifiers

    @Test("Multipeer service type is valid")
    func multipeerServiceType() {
        let serviceType = FlickSlidesConstants.multipeerServiceType
        // Max 15 characters, lowercase letters, numbers, hyphens only
        #expect(serviceType.count <= 15)
        #expect(serviceType == "flickslides-ctl")
    }

    @Test("Bonjour service type follows naming convention")
    func bonjourServiceType() {
        let serviceType = FlickSlidesConstants.bonjourServiceType
        #expect(serviceType.hasPrefix("_"))
        #expect(serviceType.hasSuffix("._tcp"))
        #expect(serviceType == "_flickslides._tcp")
    }

    // MARK: - Gesture Detection Thresholds

    @Test("Acceleration threshold is reasonable")
    func accelerationThreshold() {
        let threshold = FlickSlidesConstants.accelerationThreshold
        // Should be high enough to filter normal movement but low enough to detect gestures
        #expect(threshold >= 1.0)  // At least 1g
        #expect(threshold <= 3.0)  // Not too sensitive
    }

    @Test("Rotation threshold is in degrees per second")
    func rotationThreshold() {
        let threshold = FlickSlidesConstants.rotationThreshold
        // Reasonable range for wrist rotation detection
        #expect(threshold >= 15.0)
        #expect(threshold <= 60.0)
    }

    @Test("Debounce interval prevents rapid triggers")
    func debounceInterval() {
        let interval = FlickSlidesConstants.gestureDebounceInterval
        // Should be long enough to prevent accidental double-triggers
        #expect(interval >= 0.5)
        #expect(interval <= 2.0)
    }

    @Test("Gesture timeout allows completion")
    func gestureTimeout() {
        let timeout = FlickSlidesConstants.gestureTimeout
        // Should give enough time to complete gesture
        #expect(timeout >= 0.5)
        #expect(timeout <= 3.0)
    }

    @Test("Minimum gesture duration filters accidental triggers")
    func minGestureDuration() {
        let minDuration = FlickSlidesConstants.gestureMinDuration
        // Too short = accidental, too long = unresponsive
        #expect(minDuration >= 0.05)
        #expect(minDuration <= 0.2)
    }

    // MARK: - Calibration Thresholds

    @Test("Calibration acceleration threshold is lower than detection")
    func calibrationAccelerationLower() {
        let calibration = FlickSlidesConstants.calibrationAccelerationThreshold
        let detection = FlickSlidesConstants.accelerationThreshold
        // Calibration should accept softer gestures
        #expect(calibration < detection)
    }

    @Test("Calibration min samples ensures quality")
    func calibrationMinSamples() {
        let minSamples = FlickSlidesConstants.calibrationMinSamples
        // Need enough samples for reliable pattern recognition
        #expect(minSamples >= 10)
        #expect(minSamples <= 50)
    }

    // MARK: - DTW Thresholds

    @Test("DTW confidence threshold is reasonable")
    func dtwConfidenceThreshold() {
        let threshold = FlickSlidesConstants.dtwConfidenceThreshold
        // Should require decent confidence but not be too strict
        #expect(threshold >= 0.5)
        #expect(threshold <= 0.9)
    }

    @Test("DTW pre-buffer size captures gesture start")
    func dtwPreBufferSize() {
        let size = FlickSlidesConstants.dtwPreBufferSize
        // At 50Hz, 10 samples = 200ms
        #expect(size >= 5)
        #expect(size <= 20)
    }

    // MARK: - Performance

    @Test("Max acceptable latency meets UX requirement")
    func maxLatency() {
        let latency = FlickSlidesConstants.maxAcceptableLatencyMs
        // Should be perceptually instant (< 500ms)
        #expect(latency <= 500)
        #expect(latency >= 100)
    }

    @Test("Sensor sampling rate is adequate")
    func samplingRate() {
        let rate = FlickSlidesConstants.sensorSamplingRate
        // 50Hz is standard for gesture recognition
        #expect(rate >= 30.0)
        #expect(rate <= 100.0)
    }

    @Test("Mac command cooldown prevents spam")
    func macCooldown() {
        let cooldown = FlickSlidesConstants.macCommandCooldown
        // Should prevent accidental rapid commands
        #expect(cooldown >= 0.3)
        #expect(cooldown <= 1.0)
    }
}

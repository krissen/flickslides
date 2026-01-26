import Foundation
import Testing
@testable import FlickSlidesKit

@Suite("OutlierDetector")
struct OutlierDetectorTests {

    // MARK: - Test Helpers

    private func makeSample(accX: Double = 0, accY: Double = 0, accZ: Double = 0) -> MotionSample {
        MotionSample(timestamp: 0, accX: accX, accY: accY, accZ: accZ, rotX: 0, rotY: 0, rotZ: 0)
    }

    private func makeBatch(_ samples: [MotionSample]) -> MotionSampleBatch {
        MotionSampleBatch(samples: samples)
    }

    private func makeIdenticalBatches(count: Int) -> [MotionSampleBatch] {
        let sample = makeSample(accX: 1.0, accY: 0.5, accZ: 0.2)
        return (0..<count).map { _ in makeBatch([sample, sample, sample]) }
    }

    // MARK: - Initialization Tests

    @Test("OutlierDetector initializes with default values")
    func initDefaultValues() {
        let detector = OutlierDetector()
        #expect(detector.outlierThreshold == 1.5)
        #expect(detector.minSamplesToKeep == 8)
        #expect(detector.maxSamplesToKeep == 15)
    }

    @Test("OutlierDetector initializes with custom values")
    func initCustomValues() {
        let detector = OutlierDetector(outlierThreshold: 2.0, minSamplesToKeep: 5, maxSamplesToKeep: 10)
        #expect(detector.outlierThreshold == 2.0)
        #expect(detector.minSamplesToKeep == 5)
        #expect(detector.maxSamplesToKeep == 10)
    }

    // MARK: - Analysis Tests

    @Test("analyze returns all samples when count <= 2")
    func analyzeSmallSet() {
        let detector = OutlierDetector()
        let batches = makeIdenticalBatches(count: 2)

        let result = detector.analyze(batches)

        #expect(result.kept.count == 2)
        #expect(result.removed.isEmpty)
    }

    @Test("analyze keeps similar samples")
    func analyzeSimilarSamples() {
        let detector = OutlierDetector(minSamplesToKeep: 3, maxSamplesToKeep: 10)

        // Create 5 similar batches
        let batches = makeIdenticalBatches(count: 5)

        let result = detector.analyze(batches)

        // All should be kept since they're identical
        #expect(result.kept.count == 5)
        #expect(result.removed.isEmpty)
    }

    @Test("analyze removes outliers")
    func analyzeRemovesOutliers() {
        let detector = OutlierDetector(outlierThreshold: 1.2, minSamplesToKeep: 3, maxSamplesToKeep: 10)

        // Create 4 similar batches
        var batches = makeIdenticalBatches(count: 4)

        // Add one very different batch (outlier)
        let outlierSamples = [
            makeSample(accX: 100.0, accY: 100.0, accZ: 100.0),
            makeSample(accX: 100.0, accY: 100.0, accZ: 100.0)
        ]
        batches.append(makeBatch(outlierSamples))

        let result = detector.analyze(batches)

        // The outlier should be removed
        #expect(result.kept.count >= 3)
        #expect(result.removed.count >= 1)
    }

    @Test("analyze respects minSamplesToKeep")
    func analyzeRespectsMinKeep() {
        let detector = OutlierDetector(outlierThreshold: 0.1, minSamplesToKeep: 4, maxSamplesToKeep: 10)

        // Create samples with varying distances
        var batches: [MotionSampleBatch] = []
        for i in 0..<5 {
            let samples = [makeSample(accX: Double(i) * 0.5)]
            batches.append(makeBatch(samples))
        }

        let result = detector.analyze(batches)

        // Even with aggressive threshold, should keep minSamplesToKeep
        #expect(result.kept.count >= 4)
    }

    @Test("analyze respects maxSamplesToKeep")
    func analyzeRespectsMaxKeep() {
        let detector = OutlierDetector(outlierThreshold: 10.0, minSamplesToKeep: 3, maxSamplesToKeep: 5)

        // Create 10 identical batches
        let batches = makeIdenticalBatches(count: 10)

        let result = detector.analyze(batches)

        // Should cap at maxSamplesToKeep
        #expect(result.kept.count <= 5)
    }

    // MARK: - Variance Tests

    @Test("varianceIsHigh detects high variance")
    func varianceIsHighDetection() {
        let lowVarianceResult = OutlierDetector.AnalysisResult(
            kept: [],
            removed: [],
            averageDistances: [1.0, 1.1, 1.05],
            medianDistance: 1.0,
            variance: 0.01  // Low variance
        )
        #expect(!lowVarianceResult.varianceIsHigh)

        let highVarianceResult = OutlierDetector.AnalysisResult(
            kept: [],
            removed: [],
            averageDistances: [1.0, 2.0, 3.0],
            medianDistance: 1.0,
            variance: 1.0  // High variance (stdDev = 1.0, 100% of median)
        )
        #expect(highVarianceResult.varianceIsHigh)
    }

    // MARK: - Template Conversion Tests

    @Test("toTemplates converts batches to templates")
    func toTemplatesConversion() {
        let detector = OutlierDetector()
        let batches = makeIdenticalBatches(count: 3)
        let result = OutlierDetector.AnalysisResult(
            kept: batches,
            removed: [],
            averageDistances: [0, 0, 0],
            medianDistance: 0,
            variance: 0
        )

        let templates = detector.toTemplates(result, label: .flickForward)

        #expect(templates.count == 3)
        #expect(templates.allSatisfy { $0.label == .flickForward })
    }

    // MARK: - needsMoreSamples Tests

    @Test("needsMoreSamples returns true when below target")
    func needsMoreSamplesBelowTarget() {
        let detector = OutlierDetector()
        let result = OutlierDetector.AnalysisResult(
            kept: makeIdenticalBatches(count: 3),
            removed: [],
            averageDistances: [],
            medianDistance: 1.0,
            variance: 0.01
        )

        #expect(detector.needsMoreSamples(result, targetCount: 5))
    }

    @Test("needsMoreSamples returns true when variance is high")
    func needsMoreSamplesHighVariance() {
        let detector = OutlierDetector()
        let result = OutlierDetector.AnalysisResult(
            kept: makeIdenticalBatches(count: 10),
            removed: [],
            averageDistances: [],
            medianDistance: 1.0,
            variance: 1.0  // High variance
        )

        #expect(detector.needsMoreSamples(result, targetCount: 5))
    }

    @Test("needsMoreSamples returns false when satisfied")
    func needsMoreSamplesSatisfied() {
        let detector = OutlierDetector()
        let result = OutlierDetector.AnalysisResult(
            kept: makeIdenticalBatches(count: 10),
            removed: [],
            averageDistances: [],
            medianDistance: 1.0,
            variance: 0.01  // Low variance
        )

        #expect(!detector.needsMoreSamples(result, targetCount: 5))
    }
}

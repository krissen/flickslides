import Foundation
import Testing
@testable import FlickSlidesKit

@Suite("MotionSample")
struct MotionSampleTests {

    @Test("MotionSample initializes correctly")
    func initializesCorrectly() {
        let sample = MotionSample(
            timestamp: 0.5,
            accX: 1.0, accY: 0.5, accZ: -0.2,
            rotX: 10.0, rotY: 5.0, rotZ: -3.0
        )

        #expect(sample.timestamp == 0.5)
        #expect(sample.accX == 1.0)
        #expect(sample.accY == 0.5)
        #expect(sample.accZ == -0.2)
        #expect(sample.rotX == 10.0)
        #expect(sample.rotY == 5.0)
        #expect(sample.rotZ == -3.0)
    }

    @Test("MotionSample asArray returns correct values")
    func asArrayReturnsCorrectValues() {
        let sample = MotionSample(
            timestamp: 0.0,
            accX: 1.0, accY: 2.0, accZ: 3.0,
            rotX: 4.0, rotY: 5.0, rotZ: 6.0
        )

        let array = sample.asArray
        #expect(array.count == 6)
        #expect(array[0] == 1.0)  // accX
        #expect(array[1] == 2.0)  // accY
        #expect(array[2] == 3.0)  // accZ
        #expect(array[3] == 4.0)  // rotX
        #expect(array[4] == 5.0)  // rotY
        #expect(array[5] == 6.0)  // rotZ
    }

    @Test("MotionSample encodes and decodes")
    func codable() throws {
        let sample = MotionSample(
            timestamp: 1.5,
            accX: 0.8, accY: -0.3, accZ: 0.1,
            rotX: 15.0, rotY: -5.0, rotZ: 2.0
        )

        let encoded = try JSONEncoder().encode(sample)
        let decoded = try JSONDecoder().decode(MotionSample.self, from: encoded)

        #expect(decoded.timestamp == sample.timestamp)
        #expect(decoded.accX == sample.accX)
        #expect(decoded.accY == sample.accY)
        #expect(decoded.accZ == sample.accZ)
        #expect(decoded.rotX == sample.rotX)
        #expect(decoded.rotY == sample.rotY)
        #expect(decoded.rotZ == sample.rotZ)
    }
}

@Suite("GestureLabel")
struct GestureLabelTests {

    @Test("GestureLabel raw values are correct")
    func rawValuesCorrect() {
        #expect(GestureLabel.flickForward.rawValue == "flickForward")
        #expect(GestureLabel.flickBackward.rawValue == "flickBackward")
        #expect(GestureLabel.negative.rawValue == "negative")
    }

    @Test("GestureLabel encodes and decodes")
    func codable() throws {
        let labels: [GestureLabel] = [.flickForward, .flickBackward, .negative]

        for label in labels {
            let encoded = try JSONEncoder().encode(label)
            let decoded = try JSONDecoder().decode(GestureLabel.self, from: encoded)
            #expect(decoded == label)
        }
    }
}

@Suite("GestureTemplate")
struct GestureTemplateTests {

    private func makeSample(timestamp: TimeInterval = 0, accX: Double = 0) -> MotionSample {
        MotionSample(timestamp: timestamp, accX: accX, accY: 0, accZ: 0, rotX: 0, rotY: 0, rotZ: 0)
    }

    @Test("GestureTemplate initializes correctly")
    func initializesCorrectly() {
        let samples = [makeSample(timestamp: 0), makeSample(timestamp: 0.02)]
        let template = GestureTemplate(label: .flickForward, samples: samples)

        #expect(template.label == .flickForward)
        #expect(template.samples.count == 2)
        #expect(template.createdAt != nil)
    }

    @Test("GestureTemplate encodes and decodes")
    func codable() throws {
        let samples = [
            makeSample(timestamp: 0, accX: 1.0),
            makeSample(timestamp: 0.02, accX: 1.5),
            makeSample(timestamp: 0.04, accX: 0.5)
        ]
        let template = GestureTemplate(label: .flickBackward, samples: samples)

        let encoded = try JSONEncoder().encode(template)
        let decoded = try JSONDecoder().decode(GestureTemplate.self, from: encoded)

        #expect(decoded.label == template.label)
        #expect(decoded.samples.count == template.samples.count)
    }
}

@Suite("MotionSampleBatch")
struct MotionSampleBatchTests {

    private func makeSamples(count: Int, duration: TimeInterval) -> [MotionSample] {
        (0..<count).map { i in
            let t = duration * Double(i) / Double(count - 1)
            return MotionSample(timestamp: t, accX: Double(i), accY: 0, accZ: 0, rotX: 0, rotY: 0, rotZ: 0)
        }
    }

    @Test("MotionSampleBatch calculates duration correctly")
    func durationCalculation() {
        let samples = makeSamples(count: 10, duration: 0.5)
        let batch = MotionSampleBatch(samples: samples)

        // Duration should be last timestamp - first timestamp
        #expect(abs(batch.duration - 0.5) < 0.001)
    }

    @Test("MotionSampleBatch handles empty samples")
    func emptyBatch() {
        let batch = MotionSampleBatch(samples: [])
        #expect(batch.duration == 0)
        #expect(batch.samples.isEmpty)
    }

    @Test("MotionSampleBatch handles single sample")
    func singleSample() {
        let sample = MotionSample(timestamp: 0.5, accX: 1, accY: 0, accZ: 0, rotX: 0, rotY: 0, rotZ: 0)
        let batch = MotionSampleBatch(samples: [sample])
        #expect(batch.duration == 0)
        #expect(batch.samples.count == 1)
    }

    @Test("MotionSampleBatch encodes and decodes")
    func codable() throws {
        let samples = makeSamples(count: 5, duration: 0.2)
        let batch = MotionSampleBatch(samples: samples)

        let encoded = try JSONEncoder().encode(batch)
        let decoded = try JSONDecoder().decode(MotionSampleBatch.self, from: encoded)

        #expect(decoded.samples.count == batch.samples.count)
        #expect(abs(decoded.duration - batch.duration) < 0.001)
    }
}

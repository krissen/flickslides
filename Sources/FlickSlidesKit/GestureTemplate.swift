import Foundation

// MARK: - Motion Sample

/// En enstaka mätning av rörelse-sensordata.
public struct MotionSample: Codable, Sendable, Equatable {
    /// Tidpunkt relativt gestens start (sekunder)
    public let timestamp: TimeInterval
    /// Acceleration i X-led (g)
    public let accX: Double
    /// Acceleration i Y-led (g)
    public let accY: Double
    /// Acceleration i Z-led (g)
    public let accZ: Double
    /// Rotationshastighet i X-led (grader/sekund)
    public let rotX: Double
    /// Rotationshastighet i Y-led (grader/sekund)
    public let rotY: Double
    /// Rotationshastighet i Z-led (grader/sekund)
    public let rotZ: Double

    public init(
        timestamp: TimeInterval,
        accX: Double,
        accY: Double,
        accZ: Double,
        rotX: Double,
        rotY: Double,
        rotZ: Double
    ) {
        self.timestamp = timestamp
        self.accX = accX
        self.accY = accY
        self.accZ = accZ
        self.rotX = rotX
        self.rotY = rotY
        self.rotZ = rotZ
    }

    /// Returnerar alla värden som en array för DTW-beräkning.
    public var asArray: [Double] {
        [accX, accY, accZ, rotX, rotY, rotZ]
    }
}

// MARK: - Gesture Label

/// Typ av gest som en mall representerar.
public enum GestureLabel: String, Codable, CaseIterable, Sendable {
    case flickForward   // NEXT
    case flickBackward  // PREV
    case negative       // Inte en gest
}

// MARK: - Gesture Template

/// En inspelad gestmall för DTW-matchning.
public struct GestureTemplate: Codable, Identifiable, Sendable {
    public let id: UUID
    public let label: GestureLabel
    public let samples: [MotionSample]
    public let createdAt: Date

    public init(id: UUID = UUID(), label: GestureLabel, samples: [MotionSample], createdAt: Date = Date()) {
        self.id = id
        self.label = label
        self.samples = samples
        self.createdAt = createdAt
    }
}

// MARK: - Motion Sample Batch

/// En batch med motion samples, t.ex. en komplett gest-inspelning.
public struct MotionSampleBatch: Codable, Sendable {
    public let samples: [MotionSample]
    public let recordedAt: Date

    public init(samples: [MotionSample], recordedAt: Date = Date()) {
        self.samples = samples
        self.recordedAt = recordedAt
    }

    public var duration: TimeInterval {
        guard let first = samples.first, let last = samples.last else { return 0 }
        return last.timestamp - first.timestamp
    }

    public var sampleCount: Int {
        samples.count
    }
}

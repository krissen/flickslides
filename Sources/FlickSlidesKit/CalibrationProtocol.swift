import Foundation

// MARK: - Calibration Message

/// Meddelanden för kalibreringsflöde mellan Phone och Watch via WCSession.
public enum CalibrationMessage: Codable, Sendable {

    // MARK: - Phone → Watch

    /// Starta inspelning av en gest.
    case startRecording(gestureType: GestureLabel, sampleIndex: Int)

    /// Stoppa pågående inspelning.
    case stopRecording

    /// Kalibrering avbruten av användaren.
    case calibrationAborted

    /// Kalibrering är klar.
    case calibrationComplete

    /// Ping för att verifiera anslutning.
    case ping

    // MARK: - Watch → Phone

    /// Watch är redo att spela in.
    case recordingStarted

    /// En gest-sample har spelats in.
    case sampleRecorded(batch: MotionSampleBatch)

    /// Inspelning misslyckades.
    case recordingFailed(reason: String)

    /// Watch bekräftar att den är ansluten.
    case pong

    /// Watch är i kalibreringsläge.
    case watchReady

    /// Watch har lämnat kalibreringsläge.
    case watchDismissed

    /// Watch har detekterat idle (armen vilande) och är redo för nästa gest.
    case readyForGesture
}

// MARK: - Encoding/Decoding

extension CalibrationMessage {

    private enum CodingKeys: String, CodingKey {
        case type
        case gestureType
        case sampleIndex
        case batch
        case reason
    }

    private enum MessageType: String, Codable {
        case startRecording
        case stopRecording
        case calibrationAborted
        case calibrationComplete
        case ping
        case recordingStarted
        case sampleRecorded
        case recordingFailed
        case pong
        case watchReady
        case watchDismissed
        case readyForGesture
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .type)

        switch type {
        case .startRecording:
            let gestureType = try container.decode(GestureLabel.self, forKey: .gestureType)
            let sampleIndex = try container.decode(Int.self, forKey: .sampleIndex)
            self = .startRecording(gestureType: gestureType, sampleIndex: sampleIndex)
        case .stopRecording:
            self = .stopRecording
        case .calibrationAborted:
            self = .calibrationAborted
        case .calibrationComplete:
            self = .calibrationComplete
        case .ping:
            self = .ping
        case .recordingStarted:
            self = .recordingStarted
        case .sampleRecorded:
            let batch = try container.decode(MotionSampleBatch.self, forKey: .batch)
            self = .sampleRecorded(batch: batch)
        case .recordingFailed:
            let reason = try container.decode(String.self, forKey: .reason)
            self = .recordingFailed(reason: reason)
        case .pong:
            self = .pong
        case .watchReady:
            self = .watchReady
        case .watchDismissed:
            self = .watchDismissed
        case .readyForGesture:
            self = .readyForGesture
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .startRecording(let gestureType, let sampleIndex):
            try container.encode(MessageType.startRecording, forKey: .type)
            try container.encode(gestureType, forKey: .gestureType)
            try container.encode(sampleIndex, forKey: .sampleIndex)
        case .stopRecording:
            try container.encode(MessageType.stopRecording, forKey: .type)
        case .calibrationAborted:
            try container.encode(MessageType.calibrationAborted, forKey: .type)
        case .calibrationComplete:
            try container.encode(MessageType.calibrationComplete, forKey: .type)
        case .ping:
            try container.encode(MessageType.ping, forKey: .type)
        case .recordingStarted:
            try container.encode(MessageType.recordingStarted, forKey: .type)
        case .sampleRecorded(let batch):
            try container.encode(MessageType.sampleRecorded, forKey: .type)
            try container.encode(batch, forKey: .batch)
        case .recordingFailed(let reason):
            try container.encode(MessageType.recordingFailed, forKey: .type)
            try container.encode(reason, forKey: .reason)
        case .pong:
            try container.encode(MessageType.pong, forKey: .type)
        case .watchReady:
            try container.encode(MessageType.watchReady, forKey: .type)
        case .watchDismissed:
            try container.encode(MessageType.watchDismissed, forKey: .type)
        case .readyForGesture:
            try container.encode(MessageType.readyForGesture, forKey: .type)
        }
    }
}

// MARK: - WCSession Helpers

extension CalibrationMessage {

    /// Nyckel för kalibreringsmeddelanden i WCSession dictionary.
    public static let messageKey = "calibration"

    /// Konvertera till dictionary för WCSession.
    public func toDictionary() -> [String: Any] {
        guard let data = try? JSONEncoder().encode(self),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return [Self.messageKey: json]
    }

    /// Skapa från WCSession dictionary.
    public static func fromDictionary(_ dict: [String: Any]) -> CalibrationMessage? {
        guard let json = dict[messageKey] as? [String: Any],
              let data = try? JSONSerialization.data(withJSONObject: json),
              let message = try? JSONDecoder().decode(CalibrationMessage.self, from: data) else {
            return nil
        }
        return message
    }
}

// MARK: - Calibration State

/// Status för kalibreringsflödet.
public enum CalibrationPhase: Sendable, Equatable {
    case idle
    case intro
    case collectingForward(collected: Int, target: Int)
    case collectingBackward(collected: Int, target: Int)
    case collectingNegative(collected: Int, target: Int)
    case analyzing
    case needsMoreSamples(reason: String)
    case complete(stats: CalibrationStats)
    case error(message: String)
}

// MARK: - Calibration Stats

/// Statistik från en avslutad kalibrering.
public struct CalibrationStats: Sendable, Equatable {
    public let forwardKept: Int
    public let forwardRemoved: Int
    public let backwardKept: Int
    public let backwardRemoved: Int
    public let negativeKept: Int
    public let negativeRemoved: Int

    public init(
        forwardKept: Int,
        forwardRemoved: Int,
        backwardKept: Int,
        backwardRemoved: Int,
        negativeKept: Int,
        negativeRemoved: Int
    ) {
        self.forwardKept = forwardKept
        self.forwardRemoved = forwardRemoved
        self.backwardKept = backwardKept
        self.backwardRemoved = backwardRemoved
        self.negativeKept = negativeKept
        self.negativeRemoved = negativeRemoved
    }

    public var totalKept: Int {
        forwardKept + backwardKept + negativeKept
    }

    public var totalRemoved: Int {
        forwardRemoved + backwardRemoved + negativeRemoved
    }
}

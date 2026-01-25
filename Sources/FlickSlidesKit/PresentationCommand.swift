/// FlickSlidesKit
/// Delade modeller och protokoll för FlickSlides-apparna.

import Foundation

/// Kommandon som skickas från Watch via iOS till Mac.
public enum PresentationCommand: String, Codable, Sendable {
    /// Gå till nästa slide
    case next = "NEXT"

    /// Gå till föregående slide
    case previous = "PREV"

    /// Svarta skärmen (B-tangent i Keynote/PowerPoint)
    case blackout = "BLACKOUT"

    /// Avsluta presentation (Escape)
    case escape = "ESCAPE"
}

/// Bekräftelse från Mac att kommando utförts.
public struct CommandAck: Codable, Sendable {
    /// Vilket kommando som bekräftas
    public let command: String

    /// Om kommandot lyckades
    public let success: Bool

    /// Tidpunkt för utförande
    public let timestamp: Date

    public init(command: PresentationCommand, success: Bool, timestamp: Date = Date()) {
        self.command = command.rawValue
        self.success = success
        self.timestamp = timestamp
    }
}

// MARK: - Tangentbordsmappning (för macOS)

public extension PresentationCommand {
    /// Virtual keycode för detta kommando (macOS CGEvent)
    var keyCode: UInt16 {
        switch self {
        case .next:     return 124  // →
        case .previous: return 123  // ←
        case .blackout: return 11   // B
        case .escape:   return 53   // Esc
        }
    }
}

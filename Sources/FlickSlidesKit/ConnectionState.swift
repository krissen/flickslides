import Foundation

/// Anslutningsstatus för kommunikation mellan enheter.
public enum ConnectionState: Sendable {
    /// Söker efter enheter
    case searching

    /// Ansluter till enhet
    case connecting

    /// Ansluten och redo
    case connected(deviceName: String)

    /// Frånkopplad
    case disconnected

    /// Fel uppstod
    case error(String)
}

extension ConnectionState: Equatable {
    public static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.searching, .searching):
            return true
        case (.connecting, .connecting):
            return true
        case (.connected(let lName), .connected(let rName)):
            return lName == rName
        case (.disconnected, .disconnected):
            return true
        case (.error(let lErr), .error(let rErr)):
            return lErr == rErr
        default:
            return false
        }
    }
}

// MARK: - Status Colors

public extension ConnectionState {
    /// RGB-värden för statusfärger (0-1 range)
    /// Används för konsistent färgkodning på alla plattformar.
    struct StatusColor: Sendable {
        public let red: Double
        public let green: Double
        public let blue: Double

        public static let connected = StatusColor(red: 0.2, green: 0.8, blue: 0.4)    // Grön
        public static let connecting = StatusColor(red: 1.0, green: 0.6, blue: 0.0)   // Orange
        public static let searching = StatusColor(red: 0.4, green: 0.6, blue: 1.0)    // Blå
        public static let disconnected = StatusColor(red: 0.6, green: 0.6, blue: 0.6) // Grå
        public static let error = StatusColor(red: 1.0, green: 0.3, blue: 0.3)        // Röd
    }

    /// Hämta statusfärg för detta tillstånd
    var statusColor: StatusColor {
        switch self {
        case .connected:
            return .connected
        case .connecting:
            return .connecting
        case .searching:
            return .searching
        case .disconnected:
            return .disconnected
        case .error:
            return .error
        }
    }
}

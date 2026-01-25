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

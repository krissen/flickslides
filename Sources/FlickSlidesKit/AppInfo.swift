/// FlickSlidesKit
/// Modeller för app-val och meddelanden mellan Mac och iPhone.

import Foundation

/// Information om en körande app på Mac.
public struct AppInfo: Codable, Identifiable, Hashable, Sendable {
    /// Bundle identifier (t.ex. "com.apple.iWork.Keynote")
    public let id: String

    /// Visningsnamn (t.ex. "Keynote")
    public let name: String

    /// Är appen i förgrunden?
    public let isActive: Bool

    public init(id: String, name: String, isActive: Bool) {
        self.id = id
        self.name = name
        self.isActive = isActive
    }
}

/// Meddelanden mellan Mac och iPhone för app-hantering.
public enum AppMessage: Codable, Sendable {
    /// Mac -> iPhone: lista över körande presentationsappar
    case appList([AppInfo])

    /// iPhone -> Mac: välj app som mål för kommandon
    case selectApp(String)

    /// Kommando med målapp (bakåtkompatibelt: targetApp kan vara nil)
    case command(String, source: String, targetApp: String?)

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type
        case apps
        case bundleId
        case command
        case source
        case targetApp
    }

    private enum MessageType: String, Codable {
        case appList
        case selectApp
        case command
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .type)

        switch type {
        case .appList:
            let apps = try container.decode([AppInfo].self, forKey: .apps)
            self = .appList(apps)

        case .selectApp:
            let bundleId = try container.decode(String.self, forKey: .bundleId)
            self = .selectApp(bundleId)

        case .command:
            let cmd = try container.decode(String.self, forKey: .command)
            let source = try container.decode(String.self, forKey: .source)
            let targetApp = try container.decodeIfPresent(String.self, forKey: .targetApp)
            self = .command(cmd, source: source, targetApp: targetApp)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .appList(let apps):
            try container.encode(MessageType.appList, forKey: .type)
            try container.encode(apps, forKey: .apps)

        case .selectApp(let bundleId):
            try container.encode(MessageType.selectApp, forKey: .type)
            try container.encode(bundleId, forKey: .bundleId)

        case .command(let cmd, let source, let targetApp):
            try container.encode(MessageType.command, forKey: .type)
            try container.encode(cmd, forKey: .command)
            try container.encode(source, forKey: .source)
            try container.encodeIfPresent(targetApp, forKey: .targetApp)
        }
    }
}

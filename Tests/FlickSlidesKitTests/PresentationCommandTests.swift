import Foundation
import Testing
@testable import FlickSlidesKit

@Suite("PresentationCommand")
struct PresentationCommandTests {

    @Test("Keycodes are correct")
    func keycodesAreCorrect() {
        #expect(PresentationCommand.next.keyCode == 124)
        #expect(PresentationCommand.previous.keyCode == 123)
        #expect(PresentationCommand.blackout.keyCode == 11)
        #expect(PresentationCommand.escape.keyCode == 53)
    }

    @Test("Raw values match expected strings")
    func rawValuesMatch() {
        #expect(PresentationCommand.next.rawValue == "NEXT")
        #expect(PresentationCommand.previous.rawValue == "PREV")
        #expect(PresentationCommand.blackout.rawValue == "BLACKOUT")
        #expect(PresentationCommand.escape.rawValue == "ESCAPE")
    }

    @Test("CommandAck encodes and decodes")
    func commandAckCodable() throws {
        let ack = CommandAck(command: .next, success: true)
        let encoded = try JSONEncoder().encode(ack)
        let decoded = try JSONDecoder().decode(CommandAck.self, from: encoded)

        #expect(decoded.command == "NEXT")
        #expect(decoded.success == true)
    }
}

@Suite("AppInfo")
struct AppInfoTests {

    @Test("AppInfo initializes correctly")
    func appInfoInit() {
        let app = AppInfo(id: "com.apple.iWork.Keynote", name: "Keynote", isActive: true)

        #expect(app.id == "com.apple.iWork.Keynote")
        #expect(app.name == "Keynote")
        #expect(app.isActive == true)
    }

    @Test("AppInfo encodes and decodes")
    func appInfoCodable() throws {
        let app = AppInfo(id: "com.apple.Preview", name: "Preview", isActive: false)
        let encoded = try JSONEncoder().encode(app)
        let decoded = try JSONDecoder().decode(AppInfo.self, from: encoded)

        #expect(decoded.id == app.id)
        #expect(decoded.name == app.name)
        #expect(decoded.isActive == app.isActive)
    }
}

@Suite("AppMessage")
struct AppMessageTests {

    @Test("AppMessage.appList encodes and decodes")
    func appListCodable() throws {
        let apps = [
            AppInfo(id: "com.apple.iWork.Keynote", name: "Keynote", isActive: true),
            AppInfo(id: "com.microsoft.PowerPoint", name: "PowerPoint", isActive: false)
        ]
        let message = AppMessage.appList(apps)
        let encoded = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(AppMessage.self, from: encoded)

        if case .appList(let decodedApps) = decoded {
            #expect(decodedApps.count == 2)
            #expect(decodedApps[0].name == "Keynote")
            #expect(decodedApps[1].name == "PowerPoint")
        } else {
            Issue.record("Expected appList message")
        }
    }

    @Test("AppMessage.selectApp encodes and decodes")
    func selectAppCodable() throws {
        let message = AppMessage.selectApp("com.apple.iWork.Keynote")
        let encoded = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(AppMessage.self, from: encoded)

        if case .selectApp(let bundleId) = decoded {
            #expect(bundleId == "com.apple.iWork.Keynote")
        } else {
            Issue.record("Expected selectApp message")
        }
    }

    @Test("AppMessage.command encodes and decodes with targetApp")
    func commandWithTargetCodable() throws {
        let message = AppMessage.command("NEXT", source: "watch", targetApp: "com.apple.Preview")
        let encoded = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(AppMessage.self, from: encoded)

        if case .command(let cmd, let source, let targetApp) = decoded {
            #expect(cmd == "NEXT")
            #expect(source == "watch")
            #expect(targetApp == "com.apple.Preview")
        } else {
            Issue.record("Expected command message")
        }
    }

    @Test("AppMessage.command encodes and decodes without targetApp")
    func commandWithoutTargetCodable() throws {
        let message = AppMessage.command("PREV", source: "phone", targetApp: nil)
        let encoded = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(AppMessage.self, from: encoded)

        if case .command(let cmd, let source, let targetApp) = decoded {
            #expect(cmd == "PREV")
            #expect(source == "phone")
            #expect(targetApp == nil)
        } else {
            Issue.record("Expected command message")
        }
    }
}

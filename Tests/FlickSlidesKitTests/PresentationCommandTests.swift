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

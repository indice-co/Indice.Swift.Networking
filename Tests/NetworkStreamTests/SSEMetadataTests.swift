import Foundation
import Testing
@testable import NetworkStream

@Suite("SSE parser · event metadata")
struct SSEMetadataTests {
    @Test func eventTypeResetsWhileIDAndRetryPersist() throws {
        var parser = SSEParser()
        let frames = try parser.parse("id: 42\nretry: 1200\nevent: update\ndata: first\n\ndata: second\n\n")
        #expect(frames.count == 2)
        #expect(frames.map(\.eventType) == ["update", "message"])
        #expect(frames.map(\.eventID) == ["42", "42"])
        #expect(frames.map(\.retryMilliseconds) == [1200, 1200])
    }

    @Test func metadataOnlyBlocksDoNotDispatchAndEventTypeStillResets() throws {
        var parser = SSEParser()
        let frames = try parser.parse("event: ignored\nid: next\nretry: 0\n\ndata: payload\n\n")
        let frame = try #require(frames.first)
        #expect(frames.count == 1)
        #expect(frame.eventType == "message")
        #expect(frame.eventID == "next")
        #expect(frame.retryMilliseconds == 0)
    }

    @Test func nullAnywhereInIDIsIgnoredAndEmptyIDResetsIt() throws {
        var parser = SSEParser()
        let frames = try parser.parse("id: previous\nid: a\0b\ndata: one\n\nid:\ndata: two\n\n")
        #expect(frames.map(\.eventID) == ["previous", ""])
    }

    @Test(arguments: ["", "-1", "+1", "1.5", " 1", "1 ", "١", "１２", "9999999999999999999999999999"])
    func invalidRetryPreservesTheLastValidValue(_ value: String) throws {
        var parser = SSEParser()
        let frames = try parser.parse("retry: 123\nretry: \(value)\ndata: value\n\n")
        #expect(frames.first?.retryMilliseconds == 123)
    }
}

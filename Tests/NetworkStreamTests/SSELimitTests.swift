import Foundation
import Testing
@testable import NetworkStream

@Suite("SSE parser · malformed input and limits")
struct SSELimitTests {
    @Test(arguments: [[UInt8(0xFF)], [0x80], [0xC2], [0xC0, 0xAF],
                      [0xED, 0xA0, 0x80], [0xF4, 0x90, 0x80, 0x80]])
    func invalidUTF8ThrowsWhenTheLineEnds(_ bytes: [UInt8]) throws {
        var parser = SSEParser()
        for byte in bytes {
            #expect(try parser.consume(byte) == nil)
        }
        do {
            _ = try parser.consume(10)
            Issue.record("Expected invalidUTF8")
        } catch SSEError.invalidUTF8 { }
    }

    @Test func aValidReplacementCharacterIsPreserved() throws {
        var parser = SSEParser()
        #expect(try parser.parse("data: \u{FFFD}\n\n").map(\.text) == ["\u{FFFD}"])
    }

    @Test func exactLineLimitIsAllowedButTheNextByteIsRejected() throws {
        var exact = SSEParser(maximumFrameBytes: 7)
        #expect(try exact.parse("data: x\n\n").map(\.text) == ["x"])
        var oversized = SSEParser(maximumFrameBytes: 7)
        do {
            _ = try oversized.parse("data: xx")
            Issue.record("Expected frameTooLarge")
        } catch SSEError.frameTooLarge { }
    }

    @Test func accumulatedDataCountsTowardsTheLimit() throws {
        var parser = SSEParser(maximumFrameBytes: 10)
        #expect(try parser.parse("data: a\ndata: b\n").isEmpty)
        do {
            _ = try parser.parse("data: c")
            Issue.record("Expected frameTooLarge")
        } catch SSEError.frameTooLarge { }
    }

    @Test func byteCountResetsAfterAnEvent() throws {
        var parser = SSEParser(maximumFrameBytes: 7)
        #expect(try parser.parse("data: a\n\ndata: b\n\n").map(\.text) == ["a", "b"])
    }

    @Test func unterminatedCommentCannotGrowWithoutBound() throws {
        var parser = SSEParser(maximumFrameBytes: 4)
        do {
            _ = try parser.parse(":1234")
            Issue.record("Expected frameTooLarge")
        } catch SSEError.frameTooLarge { }
    }
}

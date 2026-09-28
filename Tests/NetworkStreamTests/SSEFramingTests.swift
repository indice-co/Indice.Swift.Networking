import Foundation
import Testing
@testable import NetworkStream

@Suite("SSE parser · framing and text")
struct SSEFramingTests {
    @Test(arguments: ["\n", "\r", "\r\n"])
    func supportedLineEndingsDispatchExactlyOneEvent(_ newline: String) throws {
        var parser = SSEParser()
        let frames = try parser.parse("data: first\(newline)data: second\(newline)\(newline)")
        #expect(frames.map(\.text) == ["first\nsecond"])
    }

    @Test func splitCRLFDoesNotBecomeABlankLine() throws {
        var parser = SSEParser()
        #expect(try parser.parse("data: first\r").isEmpty)
        #expect(try parser.parse("\ndata: second\r").isEmpty)
        #expect(try parser.parse("\n\r").map(\.text) == ["first\nsecond"])
        #expect(try parser.parse("\n").isEmpty)
    }

    @Test func unicodeCanArriveOneByteAtATime() throws {
        var parser = SSEParser()
        let bytes = Array("data: Γεια 👋\n\n".utf8)
        var texts: [String] = []
        for byte in bytes {
            if let frame = try parser.consume(byte) { texts.append(frame.text) }
        }
        #expect(texts == ["Γεια 👋"])
    }

    @Test func onlyTheLeadingBOMIsRemoved() throws {
        var parser = SSEParser()
        let frames = try parser.parse("\u{FEFF}data: first\n\n\u{FEFF}data: ignored\n\ndata: \u{FEFF}kept\n\n")
        #expect(frames.map(\.text) == ["first", "\u{FEFF}kept"])
    }

    @Test func commentsUnknownFieldsAndEmptyBlocksDoNotDispatch() throws {
        var parser = SSEParser()
        let frames = try parser.parse(": heartbeat\nunknown: x\nDATA: ignored\n\n\ndata: accepted\n\n")
        #expect(frames.map(\.text) == ["accepted"])
    }

    @Test func valuesLoseOnlyOneOptionalLeadingSpace() throws {
        var parser = SSEParser()
        let frames = try parser.parse("data:  indented\ndata:\ttab\ndata: value:colon\n\n")
        #expect(frames.map(\.text) == [" indented\n\ttab\nvalue:colon"])
    }

    @Test func dataWithoutAColonDispatchesAnEmptyPayload() throws {
        var parser = SSEParser()
        #expect(try parser.parse("data\n\n").map(\.text) == [""])
    }

    @Test(arguments: ["data: unfinished", "data: unfinished\n"])
    func incompleteTailDoesNotDispatch(_ tail: String) throws {
        var parser = SSEParser()
        #expect(try parser.parse("data: complete\n\n" + tail).map(\.text) == ["complete"])
    }
}

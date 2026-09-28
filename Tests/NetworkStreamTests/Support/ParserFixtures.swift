import Foundation
@testable import NetworkStream

extension SSEParser {
    mutating func parse(_ text: String) throws -> [Frame] {
        try parse(Array(text.utf8))
    }

    mutating func parse(_ bytes: [UInt8]) throws -> [Frame] {
        var frames: [Frame] = []
        for byte in bytes {
            if let frame = try consume(byte) { frames.append(frame) }
        }
        return frames
    }
}

extension SSEParser.Frame {
    var text: String { String(decoding: data, as: UTF8.self) }
}

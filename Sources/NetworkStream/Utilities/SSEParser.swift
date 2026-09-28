//
//  SSEParser.swift
//  NetworkClient
//
//  Created by Nikolas Konstantakopoulos on 28/9/26.
//

import Foundation


/// Incrementally parses a UTF-8 server-sent event stream.
/// Handles line endings, fields, and event boundaries without interpreting payloads.
struct SSEParser {

    typealias Field = SSEField
    
    struct Frame: Sendable {
        let data: Data
        let eventType: String
        let eventID: String?
        let retryMilliseconds: Int?
    }
    
    private enum LineState {
        case reading
        case afterCarriageReturn
    }
    
    private var currentLine = Data()
    private var dataLines: [String] = []
    private var eventType = ""
    private var lastEventID: String?
    private var retryMilliseconds: Int?
    
    private var lineState = LineState.reading
    private var isFirstLine = true
    private var bufferedDataByteCount = 0
    private let maximumFrameBytes: Int
    
    
    /// Application limit, defaulting to 8 MiB, for the buffered line plus accumulated
    /// data bytes. This is not a count of all received bytes or exact memory usage.
    init(maximumFrameBytes: Int = 8 * 1024 * 1024) {
        self.maximumFrameBytes = maximumFrameBytes
    }
    
    /// CR, LF, and CRLF are all line endings. Remember a CR across calls so an LF
    /// in the next network chunk does not accidentally become a second newline.
    /// Decode UTF-8 only after a complete line: a multi-byte character may span
    /// any number of reads from URLSession.AsyncBytes.
    mutating func consume(_ byte: UInt8) throws -> Frame? {
        if lineState == .afterCarriageReturn {
            lineState = .reading
            
            if byte == ASCIICharacter.lineFeed {
                return nil
            }
        }
        
        if [ASCIICharacter.carriageReturn, ASCIICharacter.lineFeed].contains(byte) {
            lineState = byte == ASCIICharacter.carriageReturn
                      ? .afterCarriageReturn
                      : .reading
            
            return try finishLine()
        }
        
        currentLine.append(byte)
        let currentLineExpectedSize = currentLine.count + bufferedDataByteCount
        
        guard currentLineExpectedSize <= maximumFrameBytes else {
            throw SSEError.frameTooLarge
        }
        
        return nil
    }
    
    // MARK: Handle stream checkpoints.
    
    private mutating func finishLine() throws -> Frame? {
        var text = String(decoding: currentLine, as: UTF8.self)

        guard text.utf8.elementsEqual(currentLine) else {
            throw SSEError.invalidUTF8
        }
        
        currentLine.removeAll(keepingCapacity: true)
        
        if isFirstLine {
            isFirstLine = false
            text = text.clearingBOMCharacter()
        }
        
        // Only a blank line commits an event.
        // Discard an incomplete event at EOF, as required by the SSE protocol.
        guard !text.isEmpty else {
            return finishEvent()
        }
        
        if text.hasPrefix(":") {
            // Heartbeat/comment, not an event.
            return nil
        }
        
        let separator = text.firstIndex(of: ":")
        let fieldName = separator.map { String(text[..<$0]) } ?? text
        
        guard let field = Field(rawValue: fieldName) else {
            // Unknown SSE fields are allowed by the protocol.
            return nil
        }
        
        let value = separator
            .map {
                let indexAfter = text.index(after: $0)
                let value = text[indexAfter...]
                
                return String(value)
            }
            // SSE removes exactly ONE optional space, not all leading whitespace.
            // Preserve all remaining whitespace in the value.
            .map { $0.clearingSingleLeadingSpace() }
        ?? ""
        
        switch field {
        case .event:
            eventType = value
            
        case .id:
            if !value.contains(ASCIICharacter.nullCharacter) {
                lastEventID = value
            }

        case .data:
            // Include the newline associated with each data line.
            bufferedDataByteCount += value.utf8.count + 1
            guard bufferedDataByteCount <= maximumFrameBytes else {
                throw SSEError.frameTooLarge
            }
            
            dataLines.append(value)
            
        case .retry:
            if !value.isEmpty,
               value.utf8.allSatisfy({ $0.isASCIIDigit }),
               let milliseconds = Int(value)
            {
                retryMilliseconds = milliseconds
            }
        }
        
        return nil
    }
    
    private mutating func finishEvent() -> Frame? {
        // Event ID and retry metadata persist across events.
        defer {
            dataLines.removeAll(keepingCapacity: true)
            bufferedDataByteCount = 0
            eventType = ""
        }
        
        guard !dataLines.isEmpty else { return nil }
        
        let linesData = Data(dataLines.joined(separator: "\n").utf8)
        let eventType = eventType.isEmpty ? "message" : eventType
        
        return Frame(data: linesData,
                     eventType: eventType,
                     eventID: lastEventID,
                     retryMilliseconds: retryMilliseconds)
    }
    
}


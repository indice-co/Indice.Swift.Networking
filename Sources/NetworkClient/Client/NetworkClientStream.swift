//
//  NetworkClientStream.swift
//  NetworkClient
//
//  Created by Nikolas Konstantakopoulos on 8/7/26.
//

import Foundation


extension NetworkClient {
    
    private func finalStreamFetch(_ request: URLRequest) async throws -> StreamResult {
        
        logging.log(request: request, type: .info)
        
        let (bytes, response) = try await self.session.bytes(for: request)
        let validated = try await validate(data: Data(), response: response)
        
        return (bytes, validated.response)
    }
    
    private func processStreamRequest(_ request: URLRequest, withInterceptors interceptors: [StreamInterceptor]) async throws -> StreamResult {
        guard !interceptors.isEmpty else {
            return try await finalStreamFetch(request)
        }
        
        var interceptorList = interceptors
        let current = interceptorList.removeFirst()
        let leftOvers = interceptorList
        
        return try await current.process(request) { [weak self] processedRequest in
            guard let self = self else { throw errorOfType(.unknown) }
            return try await self.processStreamRequest(processedRequest, withInterceptors: leftOvers)
        }
    }
    
    
    /// Create an SSE stream.
    public func openSSEStream<Payload: Sendable & Decodable>(
        _ eventType: Payload.Type,
        request: URLRequest
    ) async throws -> Response<AsyncThrowingStream<ServerSentEvent<Payload>, Swift.Error>> {
        
        let (bytes, response) = try await processStreamRequest(request, withInterceptors: streamInterceptors)
        
        let stream = AsyncThrowingStream<ServerSentEvent<Payload>, Swift.Error> { continuation in
            let SSEDecoder = ServerSentEventDecoder<Payload>(decoder: self.decoder)
            
            let task = Task {
                do {
                    for try await line in bytes.lines {
                        if let event = try SSEDecoder.consume(line: line) {
                            continuation.yield(event)
                        }
                    }
                    
                    if let payload = try SSEDecoder.flush() {
                        continuation.yield(payload)
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
        
        return .init(stream, httpResponse: response)
    }
    
}


public struct ServerSentEvent<Payload: Sendable & Decodable>: Sendable {
    public let event: String?
    public let data: Payload
    public let id: String?
    public let retry: TimeInterval?
}


private final class ServerSentEventDecoder<Payload: Sendable & Decodable> {
    
    typealias Event = ServerSentEvent<Payload>
    
    private enum FieldType: String {
        case event
        case data
        case id
        case retry
    }
    
    private var currentEvent: String?
    private var currentId: String?
    private var currentRetry: TimeInterval?
    private var accumulator : [String] = []
    
    private let decoder: NetworkClient.Decoder
    
    init(decoder: NetworkClient.Decoder) {
        self.decoder = decoder
    }
    
    func consume(line: String) throws -> ServerSentEvent<Payload>? {
        if line.starts(with: ":") {
            return nil
        }
        
        if line.isEmpty {
            return try flush()
        }
        
        guard let (field, value) = split(line: line) else {
            return nil
        }
        
        switch field {
        case .event:
            currentEvent = value
        case .data:
            self.accumulator.append(value)
        case .id:
            currentId = value
            
        case .retry:
            if let milliseconds = Int(value) {
                let seconds = Double(milliseconds) / 1000
                currentRetry = TimeInterval(seconds)
            }
        }
        
        return nil
    }
    
    
    
    // MARK: Helpers
    
    func flush() throws -> Event? {
        let currentEvent = self.currentEvent
        let currentId = self.currentId
        let currentRetry = self.currentRetry
        let accumulator = self.accumulator
        
        self.clear()
        
        guard !accumulator.isEmpty else {
            return nil
        }
        
        let stringBlob = accumulator.joined(separator: "\n")
        guard let data = stringBlob.data(using: .utf8) else {
            throw DecodingError
                .typeMismatch(Payload.self, .init(
                    codingPath: [],
                    debugDescription: "Faulty UTF8 data: \(stringBlob)"))
        }
        
        let payload: Payload = try decoder.decode(data: data)
        
        return ServerSentEvent(event: currentEvent, data: payload, id: currentId, retry: currentRetry)
    }

    private func split(line: String) -> (field: FieldType, value: String)? {
        let parts = line.split(
            separator: ":",
            maxSplits: 1,
            omittingEmptySubsequences: false)
            .map(String.init)
        
        let field = parts[0]
        let value = parts.count > 1 ? stripLeadingSpace(fromString: parts[1]) : ""
        
        guard let field = FieldType(rawValue: field) else {
            return nil
        }
        
        return (field, value)
    }
    

    
    private func stripLeadingSpace(fromString string: String) -> String {
        var string = string
        
        if string.starts(with: " ") {
            string.removeFirst()
        }
        
        return string
    }
    
    private func stripComment(fromLine line: String) -> String {
        var line = line
        
        if line.starts(with: ":") {
            line.removeFirst()
        }
        
        if line.starts(with: " ") {
            line.removeFirst()
        }
        
        return line
    }
    
    private func clear() {
        currentEvent = nil
        currentId = nil
        currentRetry = nil
        accumulator.removeAll(keepingCapacity: true)
    }
    
}

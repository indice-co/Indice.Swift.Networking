//
//  StreamProcessor.swift
//  NetworkClient
//
//  Created by Nikolas Konstantakopoulos on 25/9/26.
//

import Foundation

/// A generic protocol for network client that supports streams ServerSentEvents.
///
/// The response type is `StreamHandle<Payload>`, that is the async iterator of the stream.
public protocol StreamProcessor: Sendable {

    typealias StreamResponse<T> = NetworkResponse<StreamHandle<ServerSentEvent<T>>>
    
    func openSSEStream<Payload: Decodable & Sendable>(
        request: URLRequest
    ) async throws -> StreamResponse<Payload>
}

public extension StreamProcessor {
    
    func openSSEStream<Payload: Decodable & Sendable>(
        _ type: Payload.Type,
        request: URLRequest
    ) async throws -> StreamResponse<Payload> {
        try await openSSEStream(request: request)
    }
}


/// Generic type of a finalized Server Sent Event, wrapping the expected `Payload.Type`.
public struct ServerSentEvent<Payload: Sendable>: Sendable {
    public let event: String?
    public let data: Payload
    public let id: String?

    /// Suggested retry interval in seconds.
    /// Exposing this value does not imply automatic reconnection.
    public let retry: TimeInterval?

    public init(
        event: String? = nil,
        data: Payload,
        id: String? = nil,
        retry: TimeInterval? = nil
    ) {
        self.event = event
        self.data = data
        self.id = id
        self.retry = retry
    }
}

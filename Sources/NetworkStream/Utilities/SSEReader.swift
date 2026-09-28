//
//  SSEReader.swift
//  NetworkClient
//
//  Created by Nikolas Konstantakopoulos on 28/9/26.
//

import Foundation
import NetworkClient
import NetworkUtilities

internal final class SSEReader<Payload: Decodable & Sendable>: @unchecked Sendable {
    // Single-consumer ownership:
    // only next() accesses the iterator and parser, and calls must be sequential.
    private var iterator: URLSession.AsyncBytes.AsyncIterator
    private var parser = SSEParser()

    private let decoder: NetworkClient.Decoder

    init(
        bytes: URLSession.AsyncBytes,
        decoder: NetworkClient.Decoder
    ) {
        self.iterator = bytes.makeAsyncIterator()
        self.decoder = decoder
    }

    func next() async throws -> ServerSentEvent<Payload>? {
        while let byte = try await iterator.next() {
            try Task.checkCancellation()

            guard let frame = try parser.consume(byte) else {
                continue
            }

            let payload: Payload

            do {
                payload = try decoder.decode(data: frame.data)
            } catch let error as DecodingError {
                throw errorOfType(.decodingError(type: error))
            }

            return ServerSentEvent(
                event: frame.eventType,
                data: payload,
                id: frame.eventID,
                retry: frame.retryMilliseconds.map {
                    TimeInterval($0) / 1_000
                }
            )
        }

        // SSE requires a terminating blank line.
        // Do not flush an incomplete event at EOF.
        return nil
    }
}

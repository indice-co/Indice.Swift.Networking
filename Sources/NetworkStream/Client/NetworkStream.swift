//
//  NetworkStream.swift
//  NetworkClient
//
//  Created by Nikolas Konstantakopoulos on 8/7/26.
//

import Foundation
import NetworkUtilities
import NetworkClient


extension NetworkClient: StreamProcessor {

    typealias StreamResult = (stream: URLSession.AsyncBytes, response: HTTPURLResponse)
    public typealias DataType<T: Sendable> = StreamHandle<ServerSentEvent<T>>
    public typealias StreamResponse<T: Sendable> = Response<DataType<T>>

    public func openSSEStream<Payload: Decodable & Sendable>(
        request: URLRequest
    ) async throws -> StreamResponse<Payload> {
        try Task.checkCancellation()

        var request = request.clearingInstanceCaching()
        request.set(header: .accept(type: .eventStream))
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let result: Response<URLSession.AsyncBytes> = try await processRequest(
            request,
            withInterceptors: interceptors,
            transport: finalStreamFetch(_:))

        let connection = result.item.task

        // Until ownership transfers to the handle, failures must close
        // the connection here.
        var handedOff = false
        defer {
            if !handedOff {
                connection.cancel()
            }
        }

        try Task.checkCancellation()

        let reader = SSEReader<Payload>(
            bytes: result.item,
            decoder: decoder
        )

        let stream = StreamHandle<ServerSentEvent<Payload>>(
            next: {
                try await reader.next()
            },
            onTermination: {
                // Reading is pull-based: there is no separate producer task.
                // Cancelling the connection also interrupts a pending read.
                connection.cancel()
            }
        )

        handedOff = true
        return .init(stream, httpResponse: result.httpResponse)
    }
}


private extension NetworkClient {

    func finalStreamFetch(
        _ request: URLRequest
    ) async throws -> Response<URLSession.AsyncBytes> {
        logging.log(request: request, type: .info)

        let (bytes, response) = try await transport.bytes(for: request)

        var handedOff = false
        defer {
            if !handedOff {
                bytes.task.cancel()
            }
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw errorOfType(.invalidResponse)
        }

        // Preserve an error body for the existing response error mapper,
        // without buffering an arbitrarily large response.
        var errorBody = Data()

        if !(200..<300).contains(httpResponse.statusCode) {
            for try await byte in bytes {
                try Task.checkCancellation()
                errorBody.append(byte)

                if errorBody.count >= 64 * 1024 {
                    break
                }
            }
        }

        // Uses the client's existing HTTP validation, logging and error mapping.
        let validated = try await validate(
            data: errorBody,
            response: httpResponse
        )

        let contentType = httpResponse
            .value(forHTTPHeaderField: "Content-Type")?
            .split(separator: ";", maxSplits: 1)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard contentType == "text/event-stream" else {
            throw SSEError.unexpectedContentType(
                httpResponse.value(forHTTPHeaderField: "Content-Type")
            )
        }

        try Task.checkCancellation()

        handedOff = true
        return .init(bytes, httpResponse: validated.httpResponse)
    }
}


public enum SSEError: Error, Sendable {
    case invalidUTF8
    case frameTooLarge
    case unexpectedContentType(String?)
}

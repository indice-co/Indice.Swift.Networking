//
//  URLSessionTransportExtensions.swift
//  NetworkClient
//
//  Created by Nikolas Konstantakopoulos on 28/9/26.
//

import Foundation
import NetworkClient

public extension URLSessionTransport {
    
    func bytes(for request: URLRequest) async throws -> (URLSession.AsyncBytes, URLResponse) {
        try await session.bytes(for: request)
    }
    
}

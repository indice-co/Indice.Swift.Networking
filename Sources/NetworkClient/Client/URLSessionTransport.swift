//
//  URLSessionTransport.swift
//  NetworkClient
//
//  Created by Nikolas Konstantakopoulos on 28/9/26.
//

import Foundation

public struct URLSessionTransport: Sendable {
    
    package let session: URLSession
    
    public init(session: URLSession) {
        self.session = session
    }
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

public extension URLSessionTransport {
    static let shared = URLSessionTransport(session: .shared)
}

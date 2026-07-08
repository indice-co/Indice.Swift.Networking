//
//  StreamInterceptorProtocol.swift
//  NetworkClient
//
//  Created by Nikolas Konstantakopoulos on 8/7/26.
//

import Foundation

public protocol StreamInterceptorProtocol: Sendable {
    typealias Result = NetworkClient.StreamResult
    
    func process(
        _ request: URLRequest,
        next: @Sendable (URLRequest) async throws -> NetworkClient.StreamResult
    ) async throws -> NetworkClient.StreamResult
}

public struct NoOpStreamAdapter : StreamInterceptorProtocol {
    public func process(
        _ request: URLRequest,
        next: @Sendable (URLRequest) async throws -> NetworkClient.StreamResult
    ) async throws -> NetworkClient.StreamResult {
        try await next(request)
    }
}

public extension StreamInterceptorProtocol where Self == NoOpStreamAdapter {
    static var noOp: StreamInterceptorProtocol { NoOpStreamAdapter() }
}


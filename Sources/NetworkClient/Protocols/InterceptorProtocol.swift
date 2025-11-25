//
//  InterceptorProtocol.swift
//  
//
//  Created by Nikolas Konstantakopoulos on 25/1/23.
//

import Foundation


public protocol InterceptorProtocol: Sendable {
    typealias Result = NetworkClient.ChainResult
    
    func process(
        _ request: URLRequest,
        next: @Sendable (URLRequest) async throws -> NetworkClient.ChainResult
    ) async throws -> NetworkClient.ChainResult
}

public struct NoOpAdapter : InterceptorProtocol {
    public func process(
        _ request: URLRequest,
        next: @Sendable (URLRequest) async throws -> NetworkClient.ChainResult
    ) async throws -> NetworkClient.ChainResult {
        try await next(request)
    }
}

public extension InterceptorProtocol where Self == NoOpAdapter {
    static var noOp: InterceptorProtocol { NoOpAdapter() }
}

//
//  InterceptorProtocol.swift
//  
//
//  Created by Nikolas Konstantakopoulos on 25/1/23.
//

import Foundation


public protocol InterceptorProtocol: AnyObject {
    typealias Result = NetworkClient.ChainResult
    
    func process(
        _ request: URLRequest,
        completion: (URLRequest) async throws -> NetworkClient.ChainResult
    ) async throws -> NetworkClient.ChainResult
}

public class NoOpAdapter : InterceptorProtocol {
    public func process(_ request: URLRequest, completion: (URLRequest) async throws -> NetworkClient.ChainResult) async throws -> NetworkClient.ChainResult {
        try await completion(request)
    }
}

public extension InterceptorProtocol where Self == NoOpAdapter {
    static var noOp: InterceptorProtocol { NoOpAdapter() }
}

//
//  InterceptorProtocol.swift
//  
//
//  Created by Nikolas Konstantakopoulos on 25/1/23.
//

import Foundation


public protocol InterceptorProtocol: AnyObject {
    func process(_ request: URLRequest, completion: (URLRequest) async throws -> NetworkClient.Result) async throws -> NetworkClient.Result
}


public class PassthroughAdapter : InterceptorProtocol {
    public func process(_ request: URLRequest, completion: (URLRequest) async throws -> NetworkClient.Result) async throws -> NetworkClient.Result {
        try await completion(request)
    }
}

public extension InterceptorProtocol where Self == PassthroughAdapter  {
    static var `default`: InterceptorProtocol { PassthroughAdapter() }
}

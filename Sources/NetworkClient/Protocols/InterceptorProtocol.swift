//
//  InterceptorProtocol.swift
//  
//
//  Created by Nikolas Konstantakopoulos on 25/1/23.
//

import Foundation
import NetworkUtilities


public protocol InterceptorProtocol: Sendable {
    typealias Result = NetworkClient.Response
    
    func process<T: Sendable>(
        _ request: URLRequest,
        next: @Sendable (URLRequest) async throws -> Result<T>
    ) async throws -> Result<T>
}

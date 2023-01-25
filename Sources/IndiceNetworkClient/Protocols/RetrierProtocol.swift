//
//  RetrierProtocol.swift
//  
//
//  Created by Nikolas Konstantakopoulos on 25/1/23.
//

import Foundation

public protocol RetrierProtocol {
    func shouldRetry(request: URLRequest) async throws -> Bool
}

public class FalseRetrier : RetrierProtocol {
    public func shouldRetry(request: URLRequest) async throws -> Bool { false }
}

public extension RetrierProtocol where Self == FalseRetrier {
    static var `default`: RetrierProtocol { FalseRetrier() }
}

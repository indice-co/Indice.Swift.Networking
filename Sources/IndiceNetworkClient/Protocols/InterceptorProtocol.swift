//
//  InterceptorProtocol.swift
//  
//
//  Created by Nikolas Konstantakopoulos on 25/1/23.
//

import Foundation


public protocol InterceptorProtocol {
    func adapt(_ request: URLRequest) async-> URLRequest
}


public class PassthroughAdapter : InterceptorProtocol {
    public func adapt(_ request: URLRequest) async -> URLRequest { request }
}

public extension InterceptorProtocol where Self == PassthroughAdapter  {
    static var `default`: InterceptorProtocol { PassthroughAdapter() }
}

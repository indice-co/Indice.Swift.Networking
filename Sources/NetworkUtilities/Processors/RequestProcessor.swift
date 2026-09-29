//
//  RequestProcessor.swift
//  NetworkClient
//
//  Created by Nikolas Konstantakopoulos on 25/9/26.
//

import Foundation

/// A generic protocol of a network client protocol.
public protocol RequestProcessor: Sendable {
    
    typealias Response<T> = NetworkResponse<T>
    
    func fetch(request: URLRequest) async throws -> Response<()>
    func fetch<D: Decodable>(request: URLRequest) async throws -> Response<D>
}

public extension RequestProcessor {
    func fetch<D: Decodable>(_ type: D.Type, request: URLRequest) async throws -> Response<D> {
        try await fetch(request: request)
    }
}

/// The response Type of the `RequestProcessor`'s methods
/// Sendable when the wrapped item is Sendable.
public struct NetworkResponse<T> {
    public let item: T
    public let httpResponse: HTTPURLResponse
    
    public init(_ item: T, httpResponse: HTTPURLResponse) {
        self.item = item
        self.httpResponse = httpResponse
    }
    
    public var allHeaders: [AnyHashable: Any] {
        httpResponse.allHeaderFields
    }
    
    public func value(forHeaderKey key: String) -> String? {
        httpResponse.value(forHTTPHeaderField: key)
    }
    
    public subscript(headerKey: String) -> String? {
        value(forHeaderKey: headerKey)
    }
}

extension NetworkResponse: Sendable where T: Sendable {}

//
//  LoggerFilter.swift
//  NetworkClient
//
//  Created by Nikolas Konstantakopoulos on 18/12/25.
//

import Foundation


public protocol LoggerFilter: Sendable {
    func acceptLoggingLevel(for request : URLRequest)      -> NetworkLoggingLevel
    func acceptLoggingLevel(for response: HTTPURLResponse) -> NetworkLoggingLevel
}

public struct AlwaysLogFilter: LoggerFilter {
    public func acceptLoggingLevel(for: URLRequest)      -> NetworkLoggingLevel { .full }
    public func acceptLoggingLevel(for: HTTPURLResponse) -> NetworkLoggingLevel { .full }
}

public extension LoggerFilter where Self == AlwaysLogFilter {
    static var always: Self { .init() }
}


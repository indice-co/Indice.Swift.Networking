//
//  LoggingInterceptor.swift
//  NetworkClient
//
//  Created by Nikolas Konstantakopoulos on 4/11/25.
//

import Foundation


public struct LoggingInterceptor: NetworkClient.Interceptor {
    
    private let logger: NetworkLogger
    
    init(
        level: NetworkLoggingLevel,
        headerMasks: [HeaderMasks] = [],
        logStream: LogStream = .default
    ) {
        self.init(logger: .default(
            logLevel: level,
            headerMasks: headerMasks,
            logStream: logStream
        ))
    }
    
    init(logger: NetworkLogger = DefaultLogger.default) {
        self.logger = logger
    }
    
    public func process(
        _ request: URLRequest,
        next: (URLRequest) async throws -> NetworkClient.ChainResult
    ) async rethrows -> NetworkClient.ChainResult {
        do {
            logger.log(request: request, type: .info)
            let response = try await next(request)
            logger.log(response: response.response, with: response.data, type: .info)
            return response
        } catch {
            logger.log(error.localizedDescription, for: .response, type: .warning)
            throw error
        }
    }
}

//
//  LoggingInterceptor.swift
//  NetworkClient
//
//  Created by Nikolas Konstantakopoulos on 4/11/25.
//

import Foundation
import NetworkUtilities


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
    
    public func process<T: Sendable>(
        _ request: URLRequest,
        next: (URLRequest) async throws -> NetworkClient.Response<T>
    ) async throws -> NetworkClient.Response<T> {
        do {
            logger.log(request: request, type: .info)
            
            let response = try await next(request)
            let data = (response.item as? Data) ?? Data()
            
            logger.log(response: response.httpResponse, with: data, type: .info)
            
            return response
        } catch {
            logger.log(error.localizedDescription, for: .response, type: .warning)
            throw error
        }
    }
}

//
//  NetworkService.swift
//  EVPulse
//
//  Created by Makis Stavropoulos on 4/1/22.
//

import Foundation


// MARK: - Client Implementation

public final class NetworkClient {
    
    public typealias Result = (Data, URLResponse)
    
    public typealias Interceptor = InterceptorProtocol
    public typealias Retrier = RetrierProtocol
    public typealias Decoder = DecoderProtocol
    public typealias Logging = NetworkLogger
    
    private let interceptors : [Interceptor]
    private let retrier : Retrier
    private let decoder : Decoder
    private let logging : Logging
    
    private var commonHeaders: [String: String]
    private var requestTasks = SynchronizedDictionary<Int, Task<Data, Error>>()
    
    public init(interceptors: [Interceptor] = [],
                retrier: Retrier = .default,
                decoder: Decoder = .default,
                logging: Logging = .default,
                commonHeaders: [String: String] = [:]) {
        self.interceptors = interceptors
        self.retrier = retrier
        self.decoder = decoder
        self.logging = logging
        self.commonHeaders = commonHeaders
    }
    
    public func addCommonHeader(name: String, value: String) {
        commonHeaders[name] = value
    }
    
    public func removeCommonHeader(name: String) {
        commonHeaders.removeValue(forKey: name)
    }
    
    public func get<D: Decodable>(path: String) async throws -> D {
        guard let url = URL(string: path) else {
            throw APIError(description: "Invalid URL: \(path)")
        }
        return try await fetch(request: URLRequest(url: url))
    }
    
    public func fetch(request: URLRequest) async throws {
        _ = try await dataFetch(request: request, customHash: nil)
    }
    
    public func fetch<D: Decodable>(request: URLRequest) async throws -> D {
        let data = try await dataFetch(request: request, customHash: nil)
        
        do {
            return try decoder.decode(data: data)
        } catch {
            if let decodingError = error as? DecodingError {
                logging.log(decodingError.description,  for: .response)
            } else {
                logging.log(error.localizedDescription, for: .response)
            }
            
            throw error
        }
    }
}

private extension NetworkClient {
    
    private func finalFetch(_ request: URLRequest) async throws -> Result {
        
        logging.log(request: request)
        
        return try await {
            if #available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *) {
                return try await URLSession.shared.data(for: request)
            } else {
                return try await URLSession.shared.asyncData(from: request)
            }
        }()
    }
    
    private func processRequest(_ request: URLRequest, withInterceptor interceptors: [Interceptor]) async throws -> Result {
        guard !interceptors.isEmpty else {
            return try await finalFetch(request)
        }
        
        var interceptorList = interceptors
        let current = interceptorList.removeFirst()
        
        return try await current.process(request) { [weak self] processedRequest in
            guard let self = self else { throw APIError.Unknown }
            return try await self.processRequest(processedRequest, withInterceptor: interceptorList)
        }
    }
    
    private func dataFetch(request initialRequest: URLRequest, customHash: Int?, canRetry: Bool = true) async throws -> Data {
        let requestKey = customHash ?? initialRequest.hashValue
        let keys = requestTasks.filter { $0.value.isCancelled }.keys
        
        requestTasks.remove(keys: keys)
        
        if let requestTask = requestTasks[requestKey] {
            return try await requestTask.value
        }
        
        logging.log("New Request: RequestKey: \(requestKey)", for: .request)
        
        let task = Task { [unowned self] () throws -> Data in
            
            defer {
                logging.log("Request: Deleted Key: \(requestKey)", for: .request)
                self.requestTasks.remove(key: requestKey)
            }
            
            var request = initialRequest // try await adapter.process(initialRequest)
            
            for (key, value) in commonHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
            
            logging.log(request: request)
            
            
            let (data, response): Result = try await processRequest(request, withInterceptor: interceptors)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.init(description: "Invalid HttpResponse from server.")
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                logging.log(response: httpResponse, with: data)
                return data
            case 401:
                logging.log(response: httpResponse, with: data)
                guard canRetry, try await retrier.shouldRetry(request: request) else {
                    throw try decoder.decodeError(response: httpResponse, data: data)
                    // throw APIError(response: httpResponse, withData: data)
                }
                
                guard canRetry else {
                    throw APIError.Unauthenticated
                }
                
                return try await dataFetch(request: request,
                                           customHash: requestKey.hashValue,
                                           canRetry: false)
            default:
                // TODO: Specific errors
                logging.log(response: httpResponse, with: nil)
                // throw APIError(response: httpResponse, withData: data)
                throw try decoder.decodeError(response: httpResponse, data: data)
            }
        }
        
        self.requestTasks[requestKey] = task
        return try await task.value
    }
}


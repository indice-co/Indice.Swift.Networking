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
    public typealias Decoder = DecoderProtocol
    public typealias Logging = NetworkLogger
    
    private let interceptors : [Interceptor]
    private let decoder  : Decoder
    private let logging  : Logging
    private var session: URLSession?
    
    private var commonHeaders: [String: String]
    private var requestTasks = SynchronizedDictionary<Int, Task<Data, Error>>()
    
    private lazy var urlSession: URLSession = {
        session ?? URLSession.shared
    }()
    
    public init(interceptors: [Interceptor] = [],
                decoder: Decoder = .default,
                logging: Logging = .default,
                session: URLSession? = nil,
                commonHeaders: [String: String] = [:]) {
        self.interceptors = interceptors
        self.session = session
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
            throw APIError(description: "Invalid URL: \(path)", code: nil)
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
    
    private func finalFetch(_ request: URLRequest) async throws -> Data {
        
        logging.log(request: request)
        
        let (data, response) = try await {
            if #available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *) {
                return try await urlSession.data(for: request)
            } else {
                return try await urlSession.asyncData(from: request)
            }
        }()
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.InvalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            logging.log(response: httpResponse, with: data)
            return data
        default:
            logging.log(response: httpResponse, with: nil)
            throw APIError(response: httpResponse, data: data)
        }
    }
    
    private func processRequest(_ request: URLRequest, withInterceptors interceptors: [Interceptor]) async throws -> Data {
        guard !interceptors.isEmpty else {
            return try await finalFetch(request)
        }
        
        var interceptorList = interceptors
        let current = interceptorList.removeFirst()
        
        return try await current.process(request) { [weak self] processedRequest in
            guard let self = self else { throw APIError.Unknown }
            return try await self.processRequest(processedRequest, withInterceptors: interceptorList)
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
            
            var request = initialRequest
            for (key, value) in commonHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
            
            return try await processRequest(request, withInterceptors: interceptors)
        }
        
        self.requestTasks[requestKey] = task
        return try await task.value
    }
}


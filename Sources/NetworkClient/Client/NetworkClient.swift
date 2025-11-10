//
//  NetworkService.swift
//  
//
//  Created by Makis Stavropoulos on 4/1/22.
//

import Foundation


// MARK: - Client Implementation

public final class NetworkClient: Sendable {
    
    public typealias  ChainResult = (data: Data, response: HTTPURLResponse)
    
    public struct Response<T>/*: Sendable where T: Sendable*/ {
        public let item: T
        public let httpResponse: HTTPURLResponse
        
        init(_ item: T, httpResponse: HTTPURLResponse) {
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
    
    internal typealias ResultTask = Task<ChainResult, Swift.Error>
    
    public typealias Interceptor = InterceptorProtocol
    public typealias Decoder = DecoderProtocol & Sendable
    public typealias Logging = NetworkLogger   & Sendable
    
    private let interceptors   : [Interceptor]
    private let apiErrorMapper : ResponseErrorMapper
    private let decoder : Decoder
    private let logging : Logging
    private let session : URLSession
    
    private let requestTasks = AtomicStorage<Int, ResultTask>()
        
    public init(interceptors: [Interceptor] = [],
                decoder: Decoder = .default,
                logging: Logging = .default,
                session: URLSession? = nil,
                apiErrorMapper: ResponseErrorMapper = .default) {
        self.interceptors = interceptors
        self.session = session ?? .shared
        self.decoder = decoder
        self.logging = logging
        self.apiErrorMapper = apiErrorMapper
    }
    
    public func get<D: Decodable>(path: String) async throws -> Response<D> {
        guard let url = URL(string: path) else {
            throw errorOfType(.invalidUrl(originalUrl: path))
        }
        
        return try await fetch(request: URLRequest(url: url))
    }
    
    public func fetch(request: URLRequest) async throws -> Response<()> {
        let result = try await dataFetch(request: request, customHash: nil)
        return .init((), httpResponse: result.response)
    }
    
    public func fetch<D: Decodable>(request: URLRequest) async throws -> Response<D> {
        let result = try await dataFetch(request: request, customHash: nil)
        
        do {
            return .init(try decoder.decode(data: result.data), httpResponse: result.response)
        } catch let err {
            if let decodingError = err as? DecodingError {
                logging.log(decodingError.description,  for: .response, type: .critical)
                throw errorOfType(.decodingError(type: decodingError))
            } else {
                logging.log(err.localizedDescription, for: .response, type: .warning)
                throw err
            }
        }
    }
}

private extension NetworkClient {
    
    private func finalFetch(_ request: URLRequest) async throws -> ChainResult {
        
        logging.log(request: request, type: .info)
        
        let (data, response) = try await {
            if #available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *) {
                return try await session.data(for: request)
            } else {
                return try await session.asyncData(from: request)
            }
        }()
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw errorOfType(.invalidResponse)
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            logging.log(response: httpResponse, with: data, type: .info)
            return (data, httpResponse)
        default:
            logging.log(response: httpResponse, with: data, type: .warning)
            throw await apiErrorMapper.map(.init(response: httpResponse, data: data))
        }
    }
    
    private func processRequest(_ request: URLRequest, withInterceptors interceptors: [Interceptor]) async throws -> ChainResult {
        guard !interceptors.isEmpty else {
            return try await finalFetch(request)
        }
        
        var interceptorList = interceptors
        let current = interceptorList.removeFirst()
        let leftOvers = interceptorList
        
        return try await current.process(request) { [weak self] processedRequest in
            guard let self = self else { throw errorOfType(.unknown) }
            return try await self.processRequest(processedRequest, withInterceptors: leftOvers)
        }
    }
    
    private func stableKey(for request: URLRequest) -> Int {
        var hasher = Hasher()
        hasher.combine(request.url?.absoluteString ?? "")
        hasher.combine(request.httpMethod ?? "GET")
        hasher.combine(request.httpBody ?? .init())
        return Int(hasher.finalize())
    }
    
    private func dataFetch(request: URLRequest, customHash: Int?, canRetry: Bool = true) async throws -> ChainResult {
        let requestKey = customHash ?? stableKey(for: request)
        await requestTasks.removeCancelled()
        
        let task = await requestTasks.getOrInsert(requestKey) {
            logging.log("New Request: RequestKey: \(requestKey)", for: .request, type: .info)
            return Task { [weak self] () throws -> ChainResult in
                guard let self else { throw errorOfType(.unknown) }
                
                let value = try await self.processRequest(request, withInterceptors: interceptors)
                
                logging.log("Request: Deleted Key: \(requestKey)", for: .request, type: .info)
                await self.requestTasks.remove(key: requestKey)
                
                return value
            }
        }
        
        return try await task.value
    }
}

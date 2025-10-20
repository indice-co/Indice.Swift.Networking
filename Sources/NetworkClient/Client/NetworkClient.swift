//
//  NetworkService.swift
//  
//
//  Created by Makis Stavropoulos on 4/1/22.
//

import Foundation


// MARK: - Client Implementation

public final actor NetworkClient {
    
    public typealias  ChainResult = (data: Data, response: HTTPURLResponse)
    
    public struct Response<T> {
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
    
    private typealias ResultTask = Task<ChainResult, Swift.Error>
    
    public typealias Interceptor = InterceptorProtocol
    public typealias Decoder = DecoderProtocol
    public typealias Logging = NetworkLogger
    
    private let interceptors   : [Interceptor]
    private let apiErrorMapper : ResponseErrorMapper
    private let decoder : Decoder
    private let logging : Logging
    private var session : URLSession?
    
    private var requestTasks = AtomicStorage<Int, ResultTask>()
    
    private lazy var urlSession: URLSession = {
        session ?? URLSession.shared
    }()
    
    public init(interceptors: [Interceptor] = [],
                decoder: Decoder = .default,
                logging: Logging = .default,
                session: URLSession? = nil,
                apiErrorMapper: ResponseErrorMapper = .default) {
        self.interceptors = interceptors
        self.session = session
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
                logging.log(decodingError.description,  for: .response)
                throw errorOfType(.decodingError(type: decodingError))
            } else {
                logging.log(err.localizedDescription, for: .response)
                throw err
            }
        }
    }
}

private extension NetworkClient {
    
    private func finalFetch(_ request: URLRequest) async throws -> ChainResult {
        
        logging.log(request: request)
        
        let (data, response) = try await {
            if #available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *) {
                return try await urlSession.data(for: request)
            } else {
                return try await urlSession.asyncData(from: request)
            }
        }()
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw errorOfType(.invalidResponse)
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            logging.log(response: httpResponse, with: data)
            return (data, httpResponse)
        default:
            logging.log(response: httpResponse, with: data)
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
    
    private func dataFetch(request: URLRequest, customHash: Int?, canRetry: Bool = true) async throws -> ChainResult {
        let requestKey = customHash ?? request.hashValue
        let keys = await requestTasks.filter { $0.value.isCancelled }.keys
        
        await requestTasks.remove(keys: keys)
        
        if let requestTask = await requestTasks.get(requestKey) {
            return try await requestTask.value
        }
        
        logging.log("New Request: RequestKey: \(requestKey)", for: .request)
        
        let task = Task { [unowned self, weak logging] () throws -> ChainResult in
            let value = try await processRequest(request, withInterceptors: interceptors)
            
            logging?.log("Request: Deleted Key: \(requestKey)", for: .request)
            await self.requestTasks.remove(key: requestKey)
            
            return value
        }
        
        await self.requestTasks.set(requestKey, to: task)
        return try await task.value
    }
}

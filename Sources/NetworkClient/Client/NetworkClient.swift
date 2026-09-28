//
//  NetworkService.swift
//  
//
//  Created by Makis Stavropoulos on 4/1/22.
//

import Foundation
import NetworkUtilities


// MARK: - Client Implementation

public final class NetworkClient: RequestProcessor {
    
    internal typealias ResultTask = Task<Response<Data>, Swift.Error>
    
    public typealias Interceptor = InterceptorProtocol
    public typealias Decoder = DecoderProtocol & Sendable
    public typealias Logging = NetworkLogger   & Sendable
    
    package let interceptors   : [Interceptor]
    package let apiErrorMapper : ResponseErrorMapper
    package let decoder   : Decoder
    package let logging   : Logging
    package let transport : URLSessionTransport
    
    private let requestTasks = AtomicStorage<String, ResultTask>()
        
    public init(interceptors: [Interceptor] = [],
                decoder: Decoder = .default.handlingOptionalResponses,
                logging: Logging = .default,
                transport: URLSessionTransport? = nil,
                apiErrorMapper: ResponseErrorMapper = .default) {
        self.interceptors = interceptors
        self.transport    = transport ?? .shared
        self.decoder = decoder
        self.logging = logging
        self.apiErrorMapper = apiErrorMapper
    }
    
    @available(*, deprecated, message: "use the default get(url:) function instead")
    public func get<D: Decodable & Sendable>(path: String) async throws -> Response<D> {
        guard let url = URL(string: path) else {
            throw errorOfType(.invalidUrl(originalUrl: path))
        }
        
        return try await fetch(request: URLRequest(url: url))
    }
    
    public func fetch(request: URLRequest) async throws -> Response<()> {
        let result = try await dataFetch(request: request)
        return .init((), httpResponse: result.httpResponse)
    }
    
    public func fetch<D: Decodable & Sendable>(request: URLRequest) async throws -> Response<D> {
        let result = try await dataFetch(request: request)
        
        do {
            return .init(
                try decoder.decode(data: result.item),
                httpResponse: result.httpResponse)
        } catch let err {
            if let decodingError = err as? DecodingError {
                logging.log(decodingError.description, for: .response, type: .critical)
                throw errorOfType(.decodingError(type: decodingError))
            } else {
                logging.log(err.localizedDescription, for: .response, type: .warning)
                throw err
            }
        }
    }
}


package extension NetworkClient {
    
    func processRequest<T: Sendable>(
        _ request: URLRequest,
        withInterceptors interceptors: [Interceptor],
        transport: @Sendable (URLRequest) async throws -> Response<T>
    ) async throws -> Response<T> {
        guard !interceptors.isEmpty else {
            return try await transport(request)
        }
        
        var interceptorList = interceptors
        let current = interceptorList.removeFirst()
        let leftOvers = interceptorList
        
        return try await current.process(request) { [weak self] processedRequest in
            guard let self = self else { throw errorOfType(.unknown) }
            return try await self.processRequest(processedRequest,
                                                 withInterceptors: leftOvers,
                                                 transport: transport)
        }
    }
    
    
    func validate(data: Data, response: URLResponse) async throws -> Response<Data> {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw errorOfType(.invalidResponse)
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            logging.log(response: httpResponse, with: data, type: .info)
            return .init(data, httpResponse: httpResponse)
        default:
            logging.log(response: httpResponse, with: data, type: .warning)
            throw await apiErrorMapper.map(.init(response: httpResponse, data: data))
        }
    }
}
    

private extension NetworkClient {
    func finalFetch(_ request: URLRequest) async throws -> Response<Data> {
        
        logging.log(request: request, type: .info)
        
        let (data, response) = try await transport.data(for: request)
        
        return try await validate(data: data, response: response)
    }
    

    
    func dataFetch(request: URLRequest) async throws -> Response<Data> {
        await requestTasks.removeCancelled()
        
        let incomingKey = request.instanceHash ?? request.stableKey()
        let requestKey = request.shouldCacheInstance ? incomingKey : incomingKey + "_" + UUID().uuidString
        
        if request.shouldCacheInstance {
            if let requestTask = await requestTasks.get(incomingKey) {
                logging.log("Cached Request: RequestKey: \(incomingKey)", for: .request, type: .info)
                return try await requestTask.value
            }
        }
        
        let task = await requestTasks.getOrInsert(requestKey) {
            logging.log("New Request: RequestKey: \(requestKey)", for: .request, type: .info)
            return Task { [weak self] () throws -> Response<Data> in
                guard let self else { throw errorOfType(.unknown) }
                                
                do {
                    let value = try await self.processRequest(
                        request.clearingInstanceCaching(),
                        withInterceptors: interceptors,
                        transport: finalFetch(_:))
                    
                    await self.requestTasks.remove(key: requestKey)
                    logging.log("Request: Deleted Key: \(requestKey)", for: .request, type: .info)
                    
                    return value
                } catch {
                    
                    await self.requestTasks.remove(key: requestKey)
                    logging.log("Request: Deleted Key: \(requestKey)", for: .request, type: .info)
                    
                    throw error
                }
            }
        }
        
        return try await task.value
    }
}

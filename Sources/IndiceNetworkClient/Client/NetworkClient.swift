//
//  NetworkService.swift
//  EVPulse
//
//  Created by Makis Stavropoulos on 4/1/22.
//

import Foundation

// MARK: - Protocols

public protocol NetworkClient_RequestAdapterProtocol {
    func adapt(_ request: URLRequest) async-> URLRequest
}

public protocol NetworkClient_RequestRetryProtocol {
    func shouldRetry(request: URLRequest) async throws -> Bool
}

public protocol NetworkClient_DecoderProvider {
    func decode<T: Decodable>(data: Data) throws -> T
    func decodeError(response: HTTPURLResponse, data: Data) throws -> APIError
}


// MARK: - Client Implementation

public final class NetworkClient {
    
    public typealias Adapter = NetworkClient_RequestAdapterProtocol
    public typealias Retrier = NetworkClient_RequestRetryProtocol
    public typealias Decoder = NetworkClient_DecoderProvider
    public typealias Logging = NetworkClient_RequestLogger
    
    // public static let shared = NetworkClient()
    
    public let adapter: Adapter
    public let retrier: Retrier
    public let decoder: Decoder
    public let logging: Logging
    
    private var commonHeaders: [String: String]
    private var requestTasks = SynchronizedDictionary<Int, Task<Data, Error>>()
    
    init(adapter: Adapter? = nil,
         retrier: Retrier? = nil,
         decoder: Decoder? = nil,
         logging: Logging? = nil,
         commonHeaders: [String: String]? = nil) {
        self.adapter = adapter ?? PassthroughAdapter()
        self.retrier = retrier ?? FalseRetrier()
        self.decoder = decoder ?? DefaultDecoder()
        self.logging = logging ?? DefaultLogger()
        self.commonHeaders = commonHeaders ?? [:]
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
            
            var request = await adapter.adapt(initialRequest)
        
            logging.log(request: request)
            
            for (key, value) in commonHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
            
            let (data, response): (Data, URLResponse) = try await {
                if #available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *) {
                    return try await URLSession.shared.data(for: request)
                } else {
                    return try await URLSession.shared.asyncData(from: request)
                }
            }()
            
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

private func printIfDebug(data: Data) {
#if DEBUG
    if let stringResponse: String = String(data: data, encoding: .utf8) {
        print(stringResponse)
    } else {
        print("Cannot parse data response as String")
    }
#endif
}

//private func handleNetworkResponse(response: HTTPURLResponse) -> NetworkError? {
//    switch response.statusCode {
//    case 200...299: return (nil)
//    case 300...399: return (NetworkError.redirectionError)
//    case 400...499: return (NetworkError.clientError)
//    case 500...599: return (NetworkError.serverError)
//    case 600: return (NetworkError.invalidRequest)
//    default: return (NetworkError.unknownError)
//    }
//}


private class PassthroughAdapter : NetworkClient.Adapter {
    func adapt(_ request: URLRequest) async -> URLRequest { request }
}

private class FalseRetrier : NetworkClient.Retrier {
    func shouldRetry(request: URLRequest) async throws -> Bool { false }
}

private class DefaultDecoder: NetworkClient.Decoder {
    
    private let defaultJSONDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(OpenISO8601DateFormatter())
        return decoder
    }()
    
    func decode<T: Decodable>(data: Data) throws -> T {
        switch T.self {
        case is Bool.Type:
            return Bool(String(data: data, encoding: .utf8)!
                    .replacingOccurrences(of: "\"", with: "")
                    .lowercased()) as! T
        case is String.Type:
            return String(decoding: data, as: UTF8.self) as! T
        default:
            return try defaultJSONDecoder.decode(T.self, from: data)
        }
    }

    func decodeError(response: HTTPURLResponse, data: Data) throws -> APIError {
        do {
            return APIError(errorData: try defaultJSONDecoder.decode(ProblemDetails.self, from: data))
        } catch {
            return APIError(description: String(data: data, encoding: .utf8)!, code: response.statusCode)
        }
    }

}

private class DefaultLogger: NetworkClient.Logging {
    
    var tag = "Network Logger"
    var requestLevel  = NetworkLoggingLevel.full
    var responseLevel = NetworkLoggingLevel.full
    
    private func canPrint(for type: NetworkLoggingType) -> Bool {
        (type == .request ? requestLevel : responseLevel) != .off
    }
    
    private func createMessage(from messages: [String]) -> [String] {
        messages.map { tag + ":: " + $0 }
    }
    
    func log(request: URLRequest) {
        guard canPrint(for: .request) else { return }
        var messages = ["START --->"]
        
        if requestLevel.contains(.status) {
            let prefix = request.method?.rawValue.uppercased() ?? "URL"
            
            if let url = request.url?.absoluteString {
                messages.append("--- \(prefix): \(url)")
            }
        }
            
        if requestLevel.contains(.headers) {
            request.allHTTPHeaderFields?.forEach {
                messages.append("--- Header: \($0.key): \($0.value)")
            }
        }
        
        if requestLevel.contains(.body), let bodyData = request.httpBody {
            if let body = try? JSONSerialization.jsonObject(with: bodyData, options: []),
               let dict = body as? [String : Any] {
                messages.append("--- Body: \(dict)")
            }
        }
        
        messages.append("END ----->")
        
        log(messages, for: .request)
    }
    
    func log(response: HTTPURLResponse, with data: Data?) {
        guard canPrint(for: .response) else { return }
        
        var messages = ["START <---"]
        
        if responseLevel.contains(.status) {
            if let url = response.url?.absoluteString {
                messages.append("--- URL: \(url)")
            }
        
            messages.append("--- Status: \(response.statusCode)")
        }
        
        if responseLevel.contains(.headers) {
            response.allHeaderFields.forEach {
                messages.append("--- Header: \($0.key): \($0.value)")
            }
        }
        
        if responseLevel.contains(.body), let bodyData = data {
            if let body = try? JSONSerialization.jsonObject(with: bodyData, options: []) {
                messages.append("--- Response Body: \(body)")
            }
        }
        
        messages.append("END <-----")
        
        log(messages, for: .response)
    }
    
    func log(_ message: String, for type: NetworkLoggingType) {
        guard canPrint(for: type) else { return }
        log([message], for: type)
    }
    
    func log(_ messages: [String], for type: NetworkLoggingType) {
        guard canPrint(for: type) else { return }
        createMessage(from: messages).forEach { print($0) }
        print()
    }
    
}

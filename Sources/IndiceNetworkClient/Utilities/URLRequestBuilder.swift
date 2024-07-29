//
//  URLRequestBuilder.swift
//
//
//  Created by Nikolas Konstantakopoulos on 4/2/22.
//

import Foundation

public protocol URLRequestResultBuilder {
    func build() -> URLRequest
}

public protocol URLRequestHeaderBuilder: URLRequestResultBuilder {
    func add(header: URLRequest.HeaderType) -> URLRequestHeaderBuilder
}

public protocol URLRequestQueryBuilder: URLRequestResultBuilder {
    func add(header: URLRequest.HeaderType) -> URLRequestHeaderBuilder
    func add(query: String, value: String?) -> URLRequestQueryBuilder
    func add(queryItems: [String: String])  -> URLRequestQueryBuilder
    func add(queryItems: [URLQueryItem])    -> URLRequestQueryBuilder
}

public protocol URLRequestBodyBuilder {
    typealias MultipartBuilder = URLRequestMultipartFormBuilder
    
    func noBody()                      -> URLRequestQueryBuilder
    func bodyJson<T: Encodable>(of: T) -> URLRequestQueryBuilder
    func bodyForm     (params: Params) -> URLRequestQueryBuilder
    func bodyFormUtf8 (params: Params) -> URLRequestQueryBuilder
    func bodyMultipart(_ builder: (MultipartBuilder) -> ()) -> URLRequestQueryBuilder
}

public protocol URLRequestMethodBuilder {
    func get   (path: String) -> URLRequestQueryBuilder
    func put   (path: String) -> URLRequestBodyBuilder
    func post  (path: String) -> URLRequestBodyBuilder
    func delete(path: String) -> URLRequestQueryBuilder
}

public protocol URLRequestMultipartFormBuilder {
    typealias FilePart = MultipartFormFilePart
    
    func add(key: String, value: String)          -> URLRequestMultipartFormBuilder
    func add(key: String, value: Data)            -> URLRequestMultipartFormBuilder
    func add(key: String, file : FilePart) throws -> URLRequestMultipartFormBuilder
}

public struct MultipartFormFilePart {
    let file: URL
    let filename: String
    let mimeType: MimeType
    
    public init(file: URL, filename: String, mimeType: MimeType) {
        self.file = file
        self.filename = filename
        self.mimeType = mimeType
    }
    
    var fileMimeType: String {
        mimeType.value(forFile: file)
    }
    
    var fileData: Data { get throws {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw errorOfType(.requestError(type: .invalidLocalFile(url: file)))
        }
        
        return try Data(contentsOf: file)
    } }
    
    public enum MimeType {
        case type(mimeType: String)
        case auto(withFallback: String = "application/octet-stream")
        
        fileprivate func value(forFile url: URL) -> String {
            switch self {
            case .type(let mimeType): mimeType
            case .auto(let fallback): url.mimeType ?? fallback
            }
        }
    }
}


extension URLRequest {
    public typealias Builder        = URLRequestMethodBuilder
    public typealias QueryBuilder   = URLRequestQueryBuilder
    public typealias ResultBuilder  = URLRequestResultBuilder
    public typealias HeaderBuilder  = URLRequestHeaderBuilder
    public typealias BodyBuilder    = URLRequestBodyBuilder
    
    public static func builder() -> Builder { URLRequestBuilder() }
    
    private class MultipartFormBuilder: BodyBuilder.MultipartBuilder {
        private let boundary: String
        private var data = Data()
        private let separator: String = "\r\n"
        
        private func disposition(_ key: String) -> String {
            "Content-Disposition: form-data; name=\"\(key)\""
        }
        
        init(boundary: String = UUID().uuidString) {
            self.boundary = boundary
        }
        
        func add(key: String, value: String) -> BodyBuilder.MultipartBuilder {
            data.append("--\(boundary)\(separator)")
            data.append(disposition(key) + separator)
            data.append(separator)
            data.append(value + separator)
            
            return self as BodyBuilder.MultipartBuilder
        }
        
        func add(key: String, value: Data) -> BodyBuilder.MultipartBuilder {
            data.append("--\(boundary)\(separator)")
            data.append(disposition(key) + separator)
            data.append(separator)
            data.append(value + separator.data(using: .utf8)!)
            
            return self as BodyBuilder.MultipartBuilder
        }
        
        func add(key: String, file: FilePart) throws -> BodyBuilder.MultipartBuilder {
            data.append("--\(boundary)\(separator)")
            data.append(disposition(key) + "; filename=\"\(file.filename)\"" + separator)
            data.append("Content-Type: \(file.fileMimeType)" + separator + separator)
            data.append(try file.fileData)
            data.append(separator)
            
            return self as BodyBuilder.MultipartBuilder
        }
        
        func makeBody() -> (boundary: String, bodyData: Data) {
            var bodyData = data
            bodyData.append("--\(boundary)--")
            return (boundary: boundary, bodyData: bodyData)
        }
    }
    
    private class URLRequestBuilder: Builder, BodyBuilder, QueryBuilder, HeaderBuilder {
        
        fileprivate var request: URLRequest!
        fileprivate var queryItems = [String:String]()
        
        fileprivate init() {}
        
        
        // MARK: - MethodBuilder
        
        func get(path: String)  -> QueryBuilder {
            request = URLRequest(url: URL(string: path)!)
            request.method = .get
            
            return self as QueryBuilder
        }
        
        func post(path: String) -> BodyBuilder {
            request = URLRequest(url: URL(string: path)!)
            request.method = .post
            
            return self as BodyBuilder
        }
        
        func put(path: String) -> BodyBuilder {
            request = URLRequest(url: URL(string: path)!)
            request.method = .put
            
            return self as BodyBuilder
        }
        
        
        func delete(path: String) -> QueryBuilder {
            request = URLRequest(url: URL(string: path)!)
            request.method = .delete
            
            return self as QueryBuilder
        }
        // MARK: - BodyBuilder
        
        func noBody() -> QueryBuilder { self as QueryBuilder }
        
        func bodyJson<T>(of object: T) -> QueryBuilder where T : Encodable {
            request.httpBody = try? JSONEncoder().encode(object)
            request.set(header: .content(type: .json))
            
            return self as QueryBuilder
        }
        
        func bodyForm(params: Params) -> QueryBuilder {
            request.httpBody = percentEncodedString(params: params).data(using: .utf8)
            request.set(header: .content(type: .url(useUTF8Charset: false)))
            
            return self as QueryBuilder
        }
        
        func bodyFormUtf8(params: Params) -> QueryBuilder {
            request.httpBody = percentEncodedString(params: params).data(using: .utf8)
            request.set(header: .content(type: .url(useUTF8Charset: true)))
            
            return self as QueryBuilder
        }
        
        func bodyMultipart(_ builder: (any MultipartBuilder) -> ()) -> any URLRequestQueryBuilder {
            let multipartBuilder = MultipartFormBuilder()
            builder(multipartBuilder)
            
            let (boundary, data) = multipartBuilder.makeBody()
            
            request.httpBody = data
            request.set(header: .content(type: .multipart(withBoundary: boundary)))
            
            return self as QueryBuilder
        }
        
        // MARK: - HeaderBuilder
        
        func add(header: URLRequest.HeaderType) -> HeaderBuilder {
            request.add(header: header)
            return self
        }
        
        
        // MARK: - QueryBuilder
        
        func add(query name: String, value: String?) -> QueryBuilder {
            if let value = value {
                queryItems[name] = value
            }

            return self as QueryBuilder
        }
        
        func add(queryItems items: [String: String])  -> QueryBuilder {
            items.forEach { queryItems[$0.key] = $0.value }
            return self as QueryBuilder
        }
        
        func add(queryItems items: [URLQueryItem])    -> QueryBuilder {
            items.forEach { queryItems[$0.name] = $0.value }
            return self as QueryBuilder
        }
        
        
        // MARK: - ResultBuilder

        func build() -> URLRequest {
            if !queryItems.isEmpty, let url = request.url {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
                let originalItems = components.queryItems ?? []

                var finalItems = originalItems.filter {
                    !queryItems.keys.contains($0.name)
                }
                
                finalItems.append(contentsOf: queryItems.map {
                    URLQueryItem(name: $0.key, value: $0.value)
                })
                
                components.queryItems = finalItems
                
                request.url = components.url
            }

            return request
        }
    }
}



// MARK: Helper extensions

fileprivate extension Data {
    
    @discardableResult
    mutating func append(_ string: String, encoding: String.Encoding = .utf8) -> Bool {
        guard let data = string.data(using: encoding) else {
            return false
        }
        
        append(data)
        return true
    }
}

fileprivate func percentEncodedString(params: Params) -> String {
    return params.map { key, value in
        let escapedKey = "\(key)".urlEncodedOrEmpty
        
        if let array = value as? [Any] {
            return array.map { entry in
                let escapedValue = "\(entry)".urlEncodedOrEmpty
                return "\(key)[]=\(escapedValue)"
            }.joined(separator: "&")
        } else {
            let escapedValue = "\(value)".urlEncodedOrEmpty
            return "\(escapedKey)=\(escapedValue)"
        }
    }
    .joined(separator: "&")
}


fileprivate extension String {
    var urlEncodedOrEmpty: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
    }
}


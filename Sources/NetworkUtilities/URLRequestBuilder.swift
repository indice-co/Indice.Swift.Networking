//
//  URLRequestBuilder.swift
//
//
//  Created by Nikolas Konstantakopoulos on 4/2/22.
//

import Foundation

public struct URLRequestBuilderOptions {
    let encoder: JSONDataEncoder
    let formEncoder: FormDataEncoder
    
    public init(encoder: JSONDataEncoder, formEncoder: FormDataEncoder) {
        self.encoder = encoder
        self.formEncoder = formEncoder
    }
}

public protocol URLRequestResultBuilder {
    func build() -> URLRequest
}

public protocol URLRequestHeaderBuilder: URLRequestResultBuilder {
    func add(header: URLRequest.HeaderType) -> URLRequestHeaderBuilder
    func add(headers: [URLRequest.HeaderType]) -> URLRequestHeaderBuilder
    func set(header: URLRequest.HeaderType) -> URLRequestHeaderBuilder
    func set(headers: [URLRequest.HeaderType]) -> URLRequestHeaderBuilder
}

public protocol URLRequestQueryBuilder: URLRequestHeaderBuilder {
    func add(query: String, value: String?) -> URLRequestQueryBuilder
    func add(queryItems: [String: String])  -> URLRequestQueryBuilder
    func add(queryItems: [URLQueryItem])    -> URLRequestQueryBuilder
}

public protocol URLRequestBodyBuilder {
    typealias MultipartBuilder = URLRequestMultipartFormBuilder
    
    func noBody()                      -> URLRequestQueryBuilder
    func bodyJson<T: Encodable>(of: T) throws -> URLRequestQueryBuilder
    func bodyForm     (params: Params) throws -> URLRequestQueryBuilder
    func bodyFormUtf8 (params: Params) throws -> URLRequestQueryBuilder
    func bodyMultipart(_ builder: (MultipartBuilder) -> ()) -> URLRequestQueryBuilder
}

public protocol URLRequestMethodBuilder {
    typealias Options = URLRequestBuilderOptions
    
    func get   (url: URL) -> URLRequestQueryBuilder
    func put   (url: URL) -> URLRequestBodyBuilder
    func post  (url: URL) -> URLRequestBodyBuilder
    func patch (url: URL) -> URLRequestBodyBuilder
    func delete(url: URL) -> URLRequestQueryBuilder
    
    @available(*, deprecated, renamed: "get(url:)", message: "Use the new non throwing replacement")
    func get   (path: String) -> URLRequestQueryBuilder
    @available(*, deprecated, renamed: "put(url:)", message: "Use the new non throwing replacement")
    func put   (path: String) -> URLRequestBodyBuilder
    @available(*, deprecated, renamed: "post(url:)", message: "Use the new non throwing replacement")
    func post  (path: String) -> URLRequestBodyBuilder
    @available(*, deprecated, renamed: "patch(url:)", message: "Use the new non throwing replacement")
    func patch (path: String) -> URLRequestBodyBuilder
    @available(*, deprecated, renamed: "delete(url:)", message: "Use the new non throwing replacement")
    func delete(path: String) -> URLRequestQueryBuilder
}

public protocol URLRequestMultipartFormBuilder {
    typealias FilePart = MultipartFormFilePart
    
    func add(key: String, value: String)          -> URLRequestMultipartFormBuilder
    func add(key: String, value: Data)            -> URLRequestMultipartFormBuilder
    func add(key: String, file : FilePart) throws -> URLRequestMultipartFormBuilder
}

public struct MultipartFormFilePart {
    public enum Error: Swift.Error {
        case invalidLocalFile(url: URL)
    }
    
    
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
            throw Error.invalidLocalFile(url: file)
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
    
    public static func builder(options: Builder.Options? = nil) -> Builder {
        URLRequestBuilder(options: options ?? .init(
            encoder: DefaultJsonEncoder(),
            formEncoder: DefaultFormEncoder()))
    }
    
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
        fileprivate var queryItems = [URLQueryItem]()
        
        fileprivate var options: Builder.Options
        
        fileprivate init(options: Builder.Options) {
            self.options = options
        }
        
        
        // MARK: - MethodBuilder
        
        func get   (path: String) -> QueryBuilder   { get   (url: URL(string: path)!) }
        func put   (path: String) -> BodyBuilder    { put   (url: URL(string: path)!) }
        func post  (path: String) -> BodyBuilder    { post  (url: URL(string: path)!) }
        func patch (path: String) -> BodyBuilder    { patch (url: URL(string: path)!) }
        func delete(path: String) -> QueryBuilder   { delete(url: URL(string: path)!) }
        
        func get(url: URL)  -> QueryBuilder {
            request = URLRequest(url: url)
            request.method = .get
            
            return self as QueryBuilder
        }
        
        func post(url: URL) -> BodyBuilder {
            request = URLRequest(url: url)
            request.method = .post
            
            return self as BodyBuilder
        }
        
        func put(url: URL) -> BodyBuilder {
            request = URLRequest(url: url)
            request.method = .put
            
            return self as BodyBuilder
        }
        
        func patch(url: URL) -> BodyBuilder {
            request = URLRequest(url: url)
            request.method = .patch
            
            return self as BodyBuilder
        }
        
        func delete(url: URL) -> QueryBuilder {
            request = URLRequest(url: url)
            request.method = .delete
            
            return self as QueryBuilder
        }
        // MARK: - BodyBuilder
        
        func noBody() -> QueryBuilder { self as QueryBuilder }
        
        func bodyJson<T>(of object: T) throws -> QueryBuilder where T : Encodable {
            request.httpBody = try options.encoder.encode(object)
            request.set(header: .content(type: .json))
            
            return self as QueryBuilder
        }
        
        func bodyForm(params: Params) throws -> QueryBuilder {
            request.httpBody = try options.formEncoder.encode(params)
            request.set(header: .content(type: .url(useUTF8Charset: false)))
            
            return self as QueryBuilder
        }
        
        func bodyFormUtf8(params: Params) throws -> QueryBuilder {
            request.httpBody = try options.formEncoder.encode(params)
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
        
        func add(headers: [URLRequest.HeaderType]) -> any URLRequestHeaderBuilder {
            headers.forEach { request.add(header: $0) }
            return self
        }

        func set(header: URLRequest.HeaderType) -> HeaderBuilder {
            request.set(header: header)
            return self
        }
        
        func set(headers: [URLRequest.HeaderType]) -> any URLRequestHeaderBuilder {
            headers.forEach { request.set(header: $0) }
            return self
        }

        
        // MARK: - QueryBuilder
        
        func add(query name: String, value: String?) -> QueryBuilder {
            if let value = value {
                queryItems.append(.init(name: name, value: value))
            }

            return self as QueryBuilder
        }
        
        func add(queryItems items: [String: String])  -> QueryBuilder {
            queryItems.append(contentsOf: items.map {
                .init(name: $0.key, value: $0.value)
            })
            return self as QueryBuilder
        }
        
        func add(queryItems items: [URLQueryItem])    -> QueryBuilder {
            queryItems.append(contentsOf: items)
            return self as QueryBuilder
        }
        
        
        // MARK: - ResultBuilder

        func build() -> URLRequest {
            if !queryItems.isEmpty, let url = request.url {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
                let originalItems = components.queryItems ?? []

                var finalItems = originalItems.filter { ogItem in
                    !queryItems.contains { $0.name == ogItem.name  }
                }
                
                finalItems.append(contentsOf: queryItems)
                
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

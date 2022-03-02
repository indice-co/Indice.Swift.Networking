//
//  URLRequestBuilder.swift
//  EVPulse
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
    func noBody()                      -> URLRequestQueryBuilder
    func bodyJson<T: Encodable>(of: T) -> URLRequestQueryBuilder
    func bodyForm     (params: Params) -> URLRequestQueryBuilder
    func bodyFormUtf8 (params: Params) -> URLRequestQueryBuilder
}

public protocol URLRequestMethodBuilder {
    func get   (path: String) -> URLRequestQueryBuilder
    func put   (path: String) -> URLRequestBodyBuilder
    func post  (path: String) -> URLRequestBodyBuilder
    func delete(path: String) -> URLRequestQueryBuilder
}

extension URLRequest {
    public typealias Builder        = URLRequestMethodBuilder
    public typealias QueryBuilder   = URLRequestQueryBuilder
    public typealias ResultBuilder  = URLRequestResultBuilder
    public typealias HeaderBuilder  = URLRequestHeaderBuilder
    public typealias BodyBuilder    = URLRequestBodyBuilder
    
    public static func builder() -> Builder { URLRequestBuilder() }
    
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
            request.add(header: .content(type: .json))
            
            return self as QueryBuilder
        }
        
        func bodyForm(params: Params) -> QueryBuilder {
            request.httpBody = percentEncodedString(params: params).data(using: .utf8)
            request.add(header: .content(type: .url))
            
            return self as QueryBuilder
        }
        
        func bodyFormUtf8(params: Params) -> QueryBuilder {
            request.httpBody = percentEncodedString(params: params).data(using: .utf8)
            request.add(header: .content(type: .urlUtf8))
            
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

fileprivate func percentEncodedString(params: Params) -> String {
    return params.map { key, value in
        let escapedKey = "\(key)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
        if let array = value as? [Any] {
            return array.map { entry in
                let escapedValue = "\(entry)"
                    .addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
                return "\(key)[]=\(escapedValue)" }.joined(separator: "&"
                )
        } else {
            let escapedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
            return "\(escapedKey)=\(escapedValue)"
        }
    }
    .joined(separator: "&")
}

// Thansks to https://stackoverflow.com/questions/26364914/http-request-in-swift-with-post-method
extension CharacterSet {
    public static let urlQueryValueAllowed: CharacterSet = {
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        return allowed
    }()
}

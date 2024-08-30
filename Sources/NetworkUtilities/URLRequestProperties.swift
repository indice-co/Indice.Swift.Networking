//
//  URLRequestExtensions.swift
//  
//
//  Created by Nikolas Konstantakopoulos on 28/1/22.
//

import Foundation

// MARK: - Helper types

extension URLRequest {
    
    public enum HTTPMethod: String {
        case get    = "GET"
        case put    = "PUT"
        case patch  = "PATCH"
        case post   = "POST"
        case delete = "DELETE"
    }
    
    public enum ContentType {
        case json
        case url(useUTF8Charset: Bool = false)
        case multipart(withBoundary: String)
        
        @available(*, deprecated, renamed: "url()", message: "Use the new url(useUTF8Charset:) to add the charset utf-8 or not")
        public static let url: ContentType = url(useUTF8Charset: false)
        
        public var value: String {
            switch self {
            case .json                    : "application/json"
            case .multipart(let boundary) : "multipart/form-data; boundary=\(boundary)"
            case .url(let useUTF8Charset) : useUTF8Charset
                ? "application/x-www-form-urlencoded; charset=utf-8"
                : "application/x-www-form-urlencoded"
            }
        }
    }
    
    public enum HeaderType {
        case authorisation (auth: String)
        case accept        (type: ContentType)
        case content       (type: ContentType)
        case language      (value: String)
        case custom        (name: String, value: String)
        
        public var name: String {
            switch self {
            case .authorisation       : return "Authorization"
            case .accept              : return "Accept"
            case .content             : return "Content-Type"
            case .language            : return "Accept-Language"
            case .custom(let name, _) : return name
            }
        }
        
        public var value: String {
            switch self {
            case .authorisation(let token)    : return token
            case .accept       (let type)     : return type.value
            case .content      (let type)     : return type.value
            case .language     (let value)    : return value
            case .custom       (_, let value) : return value
            }
        }
    }
}


// MARK: - Request constructing utilities

extension URLRequest {
    
    /** Adds a value to a header field.
     
        Any existing value of the header field will be replaced.
    */
    public mutating func set(header: HeaderType) {
        setValue(header.value, forHTTPHeaderField: header.name)
    }
    
    /** Adds a value to a header field. */
    public mutating func add(header: HeaderType) {
        addValue(header.value, forHTTPHeaderField: header.name)
    }
    
    /** Adds a value to a header field.
     
        Any existing value of the header field will be replaced.
    */
    public func setting(header: HeaderType) -> URLRequest {
        var request = self
        request.set(header: header)
        return request
    }
    
    /** Adds a value to a header field. */
    public func adding(header: HeaderType) -> URLRequest {
        var request = self
        request.add(header: header)
        return request
    }
}


// MARK: - Request method utilities

extension URLRequest {
    
    public var method: HTTPMethod? {
        get { .init(rawValue: httpMethod ?? "") }
        set { httpMethod = newValue?.rawValue   }
    }

    public static func get(path: String) -> URLRequest {
        URLRequest(url: URL(string: path)!)
    }
    
}

//
//  URLRequestExtensions.swift
//  EVPulse
//
//  Created by Nikolas Konstantakopoulos on 28/1/22.
//

import Foundation

// MARK: - Helper types

extension URLRequest {
    
    public enum HTTPMethod: String {
        case get = "GET"
        case put = "PUT"
        case patch = "PATCH"
        case post = "POST"
        case delete = "DELETE"
    }
    
    public enum ContentType: String {
        case json = "application/json"
        case url  = "application/x-www-form-urlencoded"
        case urlUtf8 = "application/x-www-form-urlencoded; charset=utf-8"
    }
    
    public enum HeaderType {
        case authorisation (auth: String)
        case accept        (type: ContentType)
        case content       (type: ContentType)
        
        public var name: String {
            switch self {
            case .authorisation : return "Authorization"
            case .accept        : return "Accept"
            case .content       : return "Content-Type"
            }
        }
        
        public var value: String {
            switch self {
            case .authorisation(let token) : return token
            case .accept       (let type)  : return type.rawValue
            case .content      (let type)  : return type.rawValue
            }
        }
    }
}


// MARK: - Request constructing utilities

extension URLRequest {
    
    public mutating func add(header: HeaderType) {
        addValue(header.value, forHTTPHeaderField: header.name)
    }
    
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

//
//  URLRequestExtensions.swift
//
//
//  Created by Nikolas Konstantakopoulos on 30/7/24.
//
//  NetworkUtilities — URLRequest convenience starters
//  Small convenience extensions that expose `URLRequest.get/put/post/...`
//  builder entry points to start fluent request construction.


import Foundation

public extension URLRequest {
    
    static func get   (url: URL) -> URLRequest.QueryBuilder { builder().get   (url: url) }
    static func put   (url: URL) -> URLRequest.BodyBuilder  { builder().put   (url: url) }
    static func post  (url: URL) -> URLRequest.BodyBuilder  { builder().post  (url: url) }
    static func patch (url: URL) -> URLRequest.BodyBuilder  { builder().patch (url: url) }
    static func delete(url: URL) -> URLRequest.QueryBuilder { builder().delete(url: url) }
}


public extension URLRequest {

    package static
    let instanceCachingKey = UUID().uuidString
    
    package static
    let instanceHashingKey = UUID().uuidString
    
    func withInstanceCaching(
        customHash: String? = nil
    ) -> URLRequest {
        var m = self
        
        m.set(header: .custom(
            name: Self.instanceCachingKey,
            value: "true"))
        
        if let customHash {
            m.set(header: .custom(
                name: Self.instanceHashingKey,
                value: customHash))
        }
        
        return m
    }
    
    package var shouldCacheInstance: Bool {
        self.allHTTPHeaderFields?[Self.instanceCachingKey] == "true"
    }
    
    package var instanceHash: String? {
        self.allHTTPHeaderFields?[Self.instanceHashingKey]
    }
    
    func clearingInstanceCaching() -> URLRequest {
        var m = self
        
        var headers = m.allHTTPHeaderFields ?? [:]
        
        headers.removeValue(forKey: Self.instanceCachingKey)
        headers.removeValue(forKey: Self.instanceHashingKey)

        m.allHTTPHeaderFields = headers

        return m
    }
    
    func stableKey() -> String {
        // TODO: define a strategy to include headers in the hash
                
        var hasher = Hasher()

        if
            let url = self.url,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        {
            let scheme = components.scheme?.lowercased() ?? ""
            let host = components.host?.lowercased() ?? ""
            let port = components.port.map { ":\($0)" } ?? ""
            let path = components.path

            var normalizedQuery = ""
            if let items = components.queryItems, !items.isEmpty {
                let sorted = items.sorted { a, b in
                    if a.name == b.name {
                        return (a.value ?? "") < (b.value ?? "")
                    }

                    return a.name < b.name
                }
                normalizedQuery = sorted.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
            }

            let normalized = "\(scheme)://\(host)\(port)\(path)\(normalizedQuery.isEmpty ? "" : "?\(normalizedQuery)")"
            hasher.combine(normalized)
        } else {
            hasher.combine(self.url?.absoluteString ?? "")
        }

        hasher.combine(self.method ?? .get)
        hasher.combine(self.httpBody ?? .init())

        return String(hasher.finalize())
    }
    
}

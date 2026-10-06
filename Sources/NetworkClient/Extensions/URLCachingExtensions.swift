//
//  URLCachingExtensions.swift
//  NetworkClient
//
//  Created by Nikolas Konstantakopoulos on 6/10/26.
//

import Foundation

package extension URLRequest {
    
    static let instanceCachingKey = UUID().uuidString
    static let instanceHashingKey = UUID().uuidString
    
    var shouldCacheInstance: Bool {
        self.allHTTPHeaderFields?[Self.instanceCachingKey] == "true"
    }
    
    var instanceHash: String? {
        self.allHTTPHeaderFields?[Self.instanceHashingKey]
    }

}
    
public extension URLRequest {
    
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
    
    
    func clearingInstanceCaching() -> URLRequest {
        var m = self
        
        m.setValue(nil, forHTTPHeaderField: Self.instanceCachingKey)
        m.setValue(nil, forHTTPHeaderField: Self.instanceHashingKey)
        
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

//
//  Helpers.swift
//  NetworkClient
//
//  Created by Nikolas Konstantakopoulos on 26/12/25.
//

import NetworkClient
import Foundation

extension URL {
   static let example = URL(string: "https://example.com")!
}

extension URLRequest {
    static let example = URLRequest(url: .example)
}


extension URLSession {
    static let failing: URLSession = {
        
        // Simulate a failing session using URLProtocol instead of subclassing URLSession.
        final class FailingProtocol: URLProtocol {
            override class func canInit(with request: URLRequest) -> Bool { true }
            override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
            override func startLoading() {
                let error = URLError(.badServerResponse)
                client?.urlProtocol(self, didFailWithError: error)
            }
            override func stopLoading() {}
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FailingProtocol.self]
        
        return URLSession(configuration: config)
    }()
    
}


/// Return a "decoded" case as the expected return type of the client fetch result.
/// 
struct MockResponseDecoder<V>: NetworkClient.Decoder {
    let response: @Sendable () -> V
    
    func decode<T>(data: Data) throws -> T where T : Decodable {
        return response() as! T
    }
}

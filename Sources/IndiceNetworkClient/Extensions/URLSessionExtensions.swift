//
//  URLSessionExtensions.swift
//  EVPulse
//
//  Created by Nikolas Konstantakopoulos on 10/2/22.
//

import Foundation

@available(iOS, deprecated: 15.0, message: "Use the built-in API instead 'data(for:)'")
public extension URLSession {
    func asyncData(from urlRequest: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = self.dataTask(with: urlRequest) { data, response, error in
                guard let data = data, let response = response else {
                    let error = error ?? URLError(.badServerResponse)
                    return continuation.resume(throwing: error)
                }
                
                continuation.resume(returning: (data, response))
            }

            task.resume()
        }
    }
}

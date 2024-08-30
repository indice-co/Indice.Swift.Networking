//
//  ResponseErrorMapper.swift
//
//
//  Created by Nikolas Konstantakopoulos on 29/7/24.
//

import Foundation

/// Handler replace the default error thrown by the `NetworkClient` on a `HTTPURLResponse` with error `statusCode`
///
/// This handler is used only if a valid `HTTPURLResponse` returns with an error status code (i.e. outside the 200 range).
public struct ResponseErrorMapper {
    
    /// Provided information about the error received by an http request
    public struct Info {
        
        /// The default error thrown by the NetworkClient
        public let error: NetworkClient.Error
        /// Error HTTP response
        public let response: HTTPURLResponse
        /// Data associated with the error response.
        public let data: Data
        
        internal init(response: HTTPURLResponse, data: Data) {
            self.error = errorOfType(.apiError(response: response, data: data))
            self.response = response
            self.data = data
        }
    }
    
    let map: (Info) async -> Swift.Error
    
    public init(map: @escaping (Info) async -> Error) {
        self.map = map
    }
    
    public static let `default` = ResponseErrorMapper { $0.error }
}

//
//  Errors.swift
//  
//
//  Created by Nikolas Konstantakopoulos on 23/7/24.
//

import Foundation

public extension NetworkClient {
    
    /// A set of possible errors that can be thrown from the `NetworkClient`
    enum Error: Swift.Error {
        /// Something unknown went bad with no info.
        case unknown
        /// A valid response from an endpoint with not successful statusCode
        case apiError(response: HTTPURLResponse, data: Data)
        /// The endpoint url is not a valid URL
        case invalidUrl(originalUrl: String)
        /// The server's response is not a valid `HTTPURLResponse`
        case invalidResponse
        /// Decoding the server's response failed. Maybe check your return types?
        case decodingError(type: DecodingError)
        /// Encoding error
        case encodingError(type: EncodingError)
        
        /// Issues regarding the request building process.
        /// Currently, creating a MultipartForm Part from a url may throw.
        case requestError(type: RequestBuildingError)
        
        
        public enum EncodingError {
            case form
            case json
        }
        
        
        public enum RequestBuildingError {
            case invalidLocalFile(url: URL)
        }
    }
}


internal func errorOfType(_ provider: @autoclosure () -> NetworkClient.Error) -> NetworkClient.Error {
    provider()
}


public extension NetworkClient.Error {
    
    var statusCode: Int? {
        guard case .apiError(let response, _) = self else {
            return nil
        }
        
        return response.statusCode
    }
    
    /// Handy extension to get the HTTPURLResponse data as a concrete type if available.
    func getError<T: Decodable>(using decoder: DecoderProtocol? = nil) -> T? {
        guard case .apiError(_, let errorData) = self else {
            return nil
        }
        if let decoder = decoder {
            return try? decoder.decode(data: errorData)
        } else {
            return try? JSONDecoder().decode(T.self, from: errorData)
        }
    }

    
}

//
//  ApiError.swift
//  EVPulse
//
//  Created by Makis Stavropoulos on 17/2/21.
//

import Foundation

public struct APIError: LocalizedError {
    
    public struct SimpleError: NetworkError {
        public let status: Int?
        public let description: String
    }
    
    public static let Unknown         = APIError(description: "Unknown Error")
    public static let Unauthenticated = APIError(description: "Unauthenticated")
    
    public let errorData: NetworkError
    
    public init(description: String, code: Int? = nil) {
        self.init(errorData: SimpleError(status: code, description: description))
    }
    
    public init(description: String) {
        self.init(description: description, code: nil)
    }
    
    public init(errorData: NetworkError) {
        self.errorData = errorData
    }
    
    public init<T: NetworkError>(response: HTTPURLResponse, withData data: Data?, type: T.Type) {
        if let errorData = data {
            if let problemDetails = try? JSONDecoder().decode(type, from: errorData) {
                self.init(errorData: problemDetails)
                return
            }
            if let errorDescription = String(data: errorData, encoding: .utf8) {
                self.init(description: errorDescription, code: response.statusCode)
                return
            }
        }
        self.init(description: response.description, code: response.statusCode)
    }
}

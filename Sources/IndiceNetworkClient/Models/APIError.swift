//
//  ApiError.swift
//  EVPulse
//
//  Created by Makis Stavropoulos on 17/2/21.
//

import Foundation

public struct APIError: LocalizedError {
    
    public static let Unknown         = APIError(description: "Unknown Error", code: nil)
    public static let Unauthenticated = APIError(description: "Unauthenticated", code: nil)
    public static let InvalidResponse = APIError(description: "Invalid HttpResponse from server", code: nil)
    

    public let errorDescription: String
    public let statusCode: Int?
    
    public let raw: Data?
    
    public init(description: String, code: Int?, data: Data? = nil) {
        self.errorDescription = description
        self.statusCode = code
        self.raw = data
    }
    
    public init(response: HTTPURLResponse, data: Data?) {
        self.init(description: HTTPURLResponse.localizedString(forStatusCode: response.statusCode),
                  code: response.statusCode,
                  data: data)
    }

    public func getError<T: Decodable>(using decoder: DecoderProtocol?) -> T? {
        if let errorData = raw {
            if let decoder = decoder {
                return try? decoder.decode(data: errorData)
            } else {
                return try? JSONDecoder().decode(T.self, from: errorData)
            }
        }
        
        return nil
    }
}

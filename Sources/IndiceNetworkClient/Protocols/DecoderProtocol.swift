//
//  DecoderProtocol.swift
//  
//
//  Created by Nikolas Konstantakopoulos on 25/1/23.
//

import Foundation

public protocol DecoderProtocol {
    func decode<T: Decodable>(data: Data) throws -> T
    func decodeError(response: HTTPURLResponse, data: Data) throws -> APIError
}


public class DefaultDecoder: DecoderProtocol {
    
    private let defaultJSONDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(TryDateFormatter())
        return decoder
    }()
    
    public func decode<T: Decodable>(data: Data) throws -> T {
        switch T.self {
        case is Bool.Type:
            return Bool(String(data: data, encoding: .utf8)!
                .replacingOccurrences(of: "\"", with: "")
                .lowercased()) as! T
        case is String.Type:
            return String(decoding: data, as: UTF8.self) as! T
        default:
            return try defaultJSONDecoder.decode(T.self, from: data)
        }
    }
    
    public func decodeError(response: HTTPURLResponse, data: Data) throws -> APIError {
        do {
            return APIError(errorData: try defaultJSONDecoder.decode(ProblemDetails.self, from: data))
        } catch {
            return APIError(description: String(data: data, encoding: .utf8)!, code: response.statusCode)
        }
    }
    
}


public extension DecoderProtocol where Self == DefaultDecoder {
    
    static var `default`: some DecoderProtocol { DefaultDecoder() }
    
}

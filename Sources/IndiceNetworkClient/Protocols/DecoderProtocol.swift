//
//  DecoderProtocol.swift
//  
//
//  Created by Nikolas Konstantakopoulos on 25/1/23.
//

import Foundation

public protocol DecoderProtocol {
    func decode<T: Decodable>(data: Data) throws -> T
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
    
}


public extension DecoderProtocol where Self == DefaultDecoder {
    
    static var `default`: some DecoderProtocol { DefaultDecoder() }
    
}

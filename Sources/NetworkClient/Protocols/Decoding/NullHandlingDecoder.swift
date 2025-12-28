//
//  NullHandlingDecoder.swift
//  NetworkClient
//
//  Created by Nikolas Konstantakopoulos on 18/12/25.
//

import Foundation

public final class NullHandlingDecoder: NetworkClient.Decoder {
    private let inner: NetworkClient.Decoder
    
    var handlingNull: NullHandlingDecoder { self }
    
    init(inner: NetworkClient.Decoder = .default) {
        self.inner = inner
    }
    
    public func decode<T>(data: Data) throws -> T where T : Decodable {
        // Check is return value is nullable
        guard T.self is ExpressibleByNilLiteral.Type else {
            return try inner.decode(data: data)
        }
        
        /* TODO: Concrete handling for "nullable"/204 responses
         
         If Data is empty, this means a "null" response.
         Should make this concrete by cheking the status code (204 probably)
         or enable different return types by status code.
         */
        guard !data.isEmpty else {
            return Optional<any Decodable>.none as! T
        }
        
        return try inner.decode(data: data)
    }
}

public extension DecoderProtocol where Self == NullHandlingDecoder {
    static var nullHandlingDefault: Self { .init() }
}

public extension DecoderProtocol where Self: Sendable {
    var handlingOptionalResponses: NullHandlingDecoder {
        NullHandlingDecoder(inner: self)
    }
}


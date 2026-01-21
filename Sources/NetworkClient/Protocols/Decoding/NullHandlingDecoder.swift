//
//  NullHandlingDecoder.swift
//  NetworkClient
//
//  Created by Nikolas Konstantakopoulos on 18/12/25.
//

import Foundation


/// This Decoder supports `Optional` response types.
///
/// In cases where the reponse __might__ be empty (e.g. status code 204 vs 200), use the `NullHandlingDecoder`
/// to "accept" an empty response Data object.
///
/// ```swift
/// let client: NetworkClient ...
///
/// func fetch() async throws -> Model? {
///     let request: URLRequest ...
///
///     // if the `client.decoder` is not NullHandlingDecoder
///     // and the response is an empty Data, this will through
///     let model = try await client.fetch(request: request)
///
///     return model
/// }
/// ```
public final class NullHandlingDecoder: NetworkClient.Decoder {
    private let inner: NetworkClient.Decoder
    
    var handlingNull: NullHandlingDecoder { self }
    
    init(inner: NetworkClient.Decoder = .default) {
        self.inner = inner
    }
    
    public func decode<T>(data: Data) throws -> T where T : Decodable {
        // Check if return value is nullable
        // ExpressibleByNilLiteral only adopted by `Optional`
        guard T.self is ExpressibleByNilLiteral.Type else {
            return try inner.decode(data: data)
        }
        
        /* TODO: Concrete handling for "nullable"/204 responses
         
         If Data is empty, this means a "null" response.
         Should make this concrete by cheking the status code (204 probably)
         or enable different return types by status code.
         */
        // TODO: Maybe this can be replaced by a more dynamic "decoding strategy"
        // i.e. check the status code, decode accordingly.
        // Also, decoding could be also not lazily on a `Response.item` getter.
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


//
//  Encoding.swift
//  NetworkClient
//
//  Created by Nikolas Konstantakopoulos on 28/1/25.
//

// MARK: - Form Encoder
import Foundation

public enum BodyEncondingError: Swift.Error {
    case json(EncodingError.Context?)
    case form
}

public protocol JSONDataEncoder: AnyObject {
    func encode<T: Encodable>(_ params: T) throws -> Data
}

public protocol FormDataEncoder: AnyObject {
    func encode(_ params: Params) throws -> Data
}




// MARK: Default implementations

public final class DefaultJsonEncoder: JSONEncoder, JSONDataEncoder, @unchecked Sendable {
    public override init() {
        super.init()
        dateEncodingStrategy = .iso8601
    }
    
    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func encode<T>(_ value: T) throws -> Data where T : Encodable {
        do {
            return try super.encode(value)
        } catch EncodingError.invalidValue(_, let context) {
            throw BodyEncondingError.json(context)
        }
    }
}

public final class DefaultFormEncoder: FormDataEncoder {
    public init() { }
    
    public func encode(_ params: Params) throws -> Data {
        guard let data = percentEncodedString(params: params).data(using: .utf8) else {
            throw BodyEncondingError.form
        }
        
        return data
    }
}


// MARK: Helpers

extension FormDataEncoder {
    public func percentEncodedString(params: Params) -> String {
        return params.map { key, value in
            let escapedKey = "\(key)".urlEncodedOrEmpty
            
            if let array = value as? [Any] {
                return array.map { entry in
                    let escapedValue = "\(entry)".urlEncodedOrEmpty
                    return "\(key)[]=\(escapedValue)"
                }.joined(separator: "&")
            } else {
                let escapedValue = "\(value)".urlEncodedOrEmpty
                return "\(escapedKey)=\(escapedValue)"
            }
        }
        .joined(separator: "&")
    }
}

fileprivate extension String {
    var urlEncodedOrEmpty: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
    }
}

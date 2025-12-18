//
//  HeaderMasks.swift
//  NetworkClient
//
//  Created by Nikolas Konstantakopoulos on 18/12/25.
//


public enum HeaderMasks: Sendable {
    case has(name: String, map: (@Sendable (String) -> String)? = nil)
    case contains(name: String, map: (@Sendable (String) -> String)? = nil)
    
    static let authorization: HeaderMasks = .has(name: "Authorization")
    
    public static let defaultTransformation: (@Sendable (String) -> String) = { value in
        String(repeating: "*", count: min(20, value.count))
    }
    
    internal var transformation: (@Sendable (String) -> String)? {
        switch self {
        case .has     (_, let map): map
        case .contains(_, let map): map
        }
    }
    
    internal func shouldMask(key: String) -> Bool {
        let shouldMask = switch self {
        case .contains(let name, _): key.contains(name)
        case .has     (let name, _): key == name
        }
        
        return shouldMask
    }
}

//
//  DateFormatter.swift
//  
//  Created by Nikolas Konstantakopoulos on 14/2/22.
//



// NetworkUtilities — Params
// Convenience typealiases and helpers for working with request parameters
// (dictionary-backed `Params` for form or query encoding).


import Foundation

public typealias Params       = [String: Any]
public typealias StringParams = [String: String]

extension Params {
    public func stringParams() -> StringParams {
        reduce(into: [String:String]()) { partialResult, element in
            if let listValue = element.value as? [Any] {
                partialResult[element.key] = listValue
                    .map { "\($0)"}
                    .joined(separator: ",")
            } else {
                partialResult[element.key] = "\(element.value)"
            }
        }
    }
}

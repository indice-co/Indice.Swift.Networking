//
//  Params.swift
//  
//
//  Created by Sacha on 13/03/2020.
//

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

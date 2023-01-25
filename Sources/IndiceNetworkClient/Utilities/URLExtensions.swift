//
//  URLExtensions.swift
//  
//
//  Created by Nikolas Konstantakopoulos on 26/2/22.
//

import Foundation

public extension URL {

    var queryParameters: [String: String]? {
        guard
            let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
            let queryItems = components.queryItems
        else { return nil }

        return queryItems.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value
        }
    }

}

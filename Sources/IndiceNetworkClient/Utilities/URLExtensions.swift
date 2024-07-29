//
//  URLExtensions.swift
//  
//
//  Created by Nikolas Konstantakopoulos on 26/2/22.
//

import Foundation

extension URL {
    public var queryParameters: [String: String]? {
        guard
            let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
            let queryItems = components.queryItems
        else { return nil }

        return queryItems.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value
        }
    }

}


// https://stackoverflow.com/questions/26364914/http-request-in-swift-with-post-method
extension CharacterSet {
    public static let urlQueryValueAllowed: CharacterSet = {
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        return allowed
    }()
}





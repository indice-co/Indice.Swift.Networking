//
//  URLRequestBuilderExtensions.swift
//  NetworkClient
//
//  Created by Nikolas Konstantakopoulos on 28/1/25.
//

import Foundation
import NetworkUtilities


public extension URLRequest.Builder {
    static func build() -> URLRequest.Builder {
        URLRequest.builder(options: .init(
            encoder: DefaultJsonEncoder(),
            formEncoder: DefaultFormEncoder()))
    }
}

//
//  ProblemDetails.swift
//  
//
//  Created by Nikolas Konstantakopoulos on 26/2/22.
//

import Foundation

public protocol NetworkError: Codable {
    var status: Int? { get }
    var description: String { get }
}

public struct ProblemDetails: NetworkError {
    
    public let detail: String?
    public let errors: [String:[String]]?
    public let status: Int?
    public let title: String?
    public let type: String?
    
    public let error_description: String?
    
    // Conformance to ServerError Protocol
    public var description: String {
        get {
            if let existingErrors = errors {
                return existingErrors.flatMap { (key: String, value: [String] ) -> [String] in
                    value
                }.joined(separator: "\n")
            }
            return detail ?? error_description ?? "Unknown Business Error Occurred"
        }
    }
}

extension ProblemDetails : Hashable {}

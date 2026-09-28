//
//  File.swift
//  
//
//  Created by Nikolas Konstantakopoulos on 30/7/24.
//

import Foundation

extension URLRequest {
    
    func configured(_ configuration: (inout URLRequest) -> ()) -> URLRequest {
        var request = self
        configuration(&request)
        
        return request
    }
}


extension String {
    
    static let alphanumerics = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    
    static func random(length: Int) -> String {
        let characters = (0..<length)
            .reduce(into: "") { acc, _ in
                let element = String
                    .alphanumerics
                    .randomElement()!
                
                acc.append(String(element))
            }
        
        return String(characters)
    }
    
    static func words(count: Int) -> String {
        (0..<count)
            .map { index in
                let wordLength = Int.random(in: 3...15)
                return String.random(length: wordLength)
            }
            .joined(separator: " ")
    }
}

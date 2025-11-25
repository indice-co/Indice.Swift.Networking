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

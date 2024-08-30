//
//  Helpers.swift
//  
//
//  Created by Nikolas Konstantakopoulos on 25/1/23.
//

import Foundation

func printIfDebug(data: Data) {
#if DEBUG
    if let stringResponse: String = String(data: data, encoding: .utf8) {
        print(stringResponse)
    } else {
        print("Cannot parse data response as String")
    }
#endif
}

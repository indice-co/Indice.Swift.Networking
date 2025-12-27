//
//  URLRequestBodyTests.swift
//  
//
//  Created by Nikolas Konstantakopoulos on 30/7/24.
//

import Testing
import Foundation
@testable import NetworkUtilities


@Suite("URLRequestBodyTests")
final class URLRequestBodyTests {
    
    private let testURL = URL(string: "https://www.indice.gr")!
    
    private let uniqueHeaders: [String: String] = (1...5).reduce(into: [:], { partialResult, value in
        partialResult["header_\(value)"] = "value_\(value)"
    })
    
    
    @Test
    func `single header (authorization)`() throws {
        let authHeader = URLRequest
            .HeaderType
            .authorisation(auth: "some_jwt")
        
        let built = URLRequest
            .get(url: testURL)
            .add(header: authHeader)
            .build()
        
        let test = URLRequest(url: testURL).configured {
            $0.addValue("some_jwt", forHTTPHeaderField: "Authorization")
        }
        
        #expect(built == test)
    }
    
    
    @Test
    func `multiple headers equality`() throws {
        let built = URLRequest.get(url: testURL)
            .add(header: .content(type: .json))
            .add(header: .accept(type: .json))
            .build()
        
        let test = URLRequest(url: testURL).configured {
            $0.addValue("application/json", forHTTPHeaderField: "Content-Type")
            $0.addValue("application/json", forHTTPHeaderField: "Accept")
        }
        
        #expect(built == test)
    }

    
    @Test
    func `multiple headers equality variant`() throws {
        let built = URLRequest.get(url: testURL)
            .add(headers: uniqueHeaders.map { .custom(name: $0, value: $1) })
            .build()
        
        let test = URLRequest(url: testURL).configured { request in
            uniqueHeaders.forEach { key, value in
                request.addValue(value, forHTTPHeaderField: key)
            }
        }
        
        #expect(built == test)
    }
}

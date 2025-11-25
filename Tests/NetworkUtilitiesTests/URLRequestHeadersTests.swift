//
//  URLRequestBodyTests.swift
//  
//
//  Created by Nikolas Konstantakopoulos on 30/7/24.
//

import XCTest
@testable import NetworkUtilities

final class URLRequestBodyTests: XCTestCase {
    
    private let testURL = URL(string: "https://www.indice.gr")!
    
    private let uniqueHeaders: [String: String] = (1...5).reduce(into: [:], { partialResult, value in
        partialResult["header_\(value)"] = "value_\(value)"
    })
    
    func testSpecificHeaders() throws {
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
        
        XCTAssertEqual(built, test)
    }
    
    
    func testMultipleHeaders() throws {
        let built = URLRequest.get(url: testURL)
            .add(header: .content(type: .json))
            .add(header: .accept(type: .json))
            .build()

        let built2 = try URLRequest.post(url: testURL)
            .bodyMultipart({ _ in
                throw NSError(domain: "", code: 0, userInfo: nil)
            })
            .build()

        
        let test = URLRequest(url: testURL).configured {
            $0.addValue("application/json", forHTTPHeaderField: "Content-Type")
            $0.addValue("application/json", forHTTPHeaderField: "Accept")
        }
        
        XCTAssertEqual(built, test)
    }

    
    func testMultipleHeaders_2() throws {
        let built = URLRequest.get(url: testURL)
            .add(headers: uniqueHeaders.map { .custom(name: $0, value: $1) })
            .build()
        
        let test = URLRequest(url: testURL).configured { request in
            uniqueHeaders.forEach { key, value in
                request.addValue(value, forHTTPHeaderField: key)
            }
        }
        
        XCTAssertEqual(built, test)
    }

    
    
    func testMultipleHeaders_3() throws {
        let sameHeaders = (1...5).map {
            URLRequest
                .HeaderType
                .custom(name: "header_name",
                        value: "value_\($0)")
        }
        
        let built = URLRequest.get(url: testURL)
            .add(headers: sameHeaders)
            .build()
        
        let test = URLRequest(url: testURL).configured { request in
            sameHeaders.forEach {
                request.addValue($0.value, forHTTPHeaderField: $0.name)
            }
        }
        
        XCTAssertEqual(built, test)
    }
    
    
}

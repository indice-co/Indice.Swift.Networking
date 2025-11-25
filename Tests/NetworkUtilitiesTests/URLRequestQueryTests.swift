//
//  URLRequestQueryTests.swift
//  NetworkClient
//
//  Created by Nikolas Konstantakopoulos on 27/12/24.
//

import Testing
import Foundation
@testable import NetworkUtilities

@Suite("URLRequest.Builder query paramters")
final class URLRequestQueryTests {
    
    private let testURL = URL(string: "https://www.indice.gr")!
    private let testURLWithQueries = URL(string: "https://www.indice.gr?name1=value1&name2=value2")!
    
    private let testQueries = [URLQueryItem(name: "name1", value: "value1"),
                               URLQueryItem(name: "name2", value: "value2")]
    @Test
    func dictionaryQueryParameters() throws {
        let built = URLRequest.builder()
            .get(url: testURL)
            .add(queryItems: [
                "name1": "value1",
                "name2": "value2"
            ])
            .build()
        
        let test = URLRequest(url: testURLWithQueries)
        
        #expect(test.url?.query == built.url?.query)
    }
    
    
    @Test
    func nativeQueryParameters() throws {
        let built = URLRequest.builder()
            .get(url: testURL)
            .add(queryItems: testQueries)
            .build()
        
        let test = URLRequest(url: testURLWithQueries)
        
        #expect(test.url?.query == built.url?.query)
    }
    
}

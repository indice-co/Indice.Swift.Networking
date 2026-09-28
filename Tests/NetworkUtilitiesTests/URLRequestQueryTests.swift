//
//  URLRequestQueryTests.swift
//  NetworkClient
//
//  Created by Nikolas Konstantakopoulos on 27/12/24.
//

import Testing
import Foundation
@testable import NetworkUtilities

@Suite("URLRequest.Builder query parameters")
final class URLRequestQueryTests {
    
    private let testURL = URL(string: "https://www.indice.gr")!
    private let testURLWithQueries = URL(string: "https://www.indice.gr?name1=value1&name2=value2&name3=value3&name4=value4&name5=value5")!
    
    private let testQueries = (1...5).map {
        URLQueryItem(name: "name\($0)", value: "value\($0)")
    }
    
    @Test
    func listQueryParameters() throws {
        let builtList = URLRequest.builder()
            .get(url: testURL)
            .add(queryItems: (1...5).map {
                .init(name: "name\($0)", value: "value\($0)")
            })
            .build()
        
        let builtDictionary = URLRequest.builder()
            .get(url: testURL)
            .add(queryItems: (1...5).reduce(into: [String: String]()) { acc, next in
                acc["name\(next)"] = "value\(next)"
            })
            .build()
        
        let test = URLRequest(url: testURLWithQueries)

        #expect(test.url?.query() == builtList.url?.query())
        
        // This should pass because the query keys of
        // the test.url are defined already sorted
        #expect(test.url?.query() == builtDictionary.url?.query())
    }

    @Test
    func listQueryParametersRandom() throws {
        let queries = (0...5).map { _ in
            URLQueryItem(
                name : String.words(count: 1),
                value: String.words(count: 1))
        }
        
        let testURL = testURL.appending(queryItems: queries)
        let test = URLRequest(url: testURL)
        
        let built = URLRequest.builder()
            .get(url: testURL)
            .add(queryItems: queries)
            .build()
        
        #expect(test.url?.query() == built.url?.query())
        
        
        let sortedByNamesRequest = URLRequest.builder()
            .get(url: testURL)
            .add(queryItems: queries.reduce(into: [String:String](), { partialResult, item in
                partialResult[item.name] = item.value
            }))
            .build()
        
        let sortedQueryNames = queries
            .sorted(by: { $0.name < $1.name  })
            .map { $0.name + "=" + $0.value! }
            .joined(separator: "&")
        
        #expect(sortedByNamesRequest.url!.query() == sortedQueryNames)
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

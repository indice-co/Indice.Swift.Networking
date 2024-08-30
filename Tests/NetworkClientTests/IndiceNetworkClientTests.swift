import XCTest
@testable import NetworkClient

final class IndiceNetworkClientTests: XCTestCase {
    
    var client = NetworkClient()
    
    func testExample() async throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        // XCTAssertEqual(IndiceNetworkClient().text, "Hello, World!")
        
        // TODO: Unit tests?
        
        let data: NetworkClient.Response<String> = try await client.fetch(request: .get(path: "https://www.example.com"))
        
        print(data.httpResponse.allHeaderFields)
        print(data.item)
        
        XCTAssert(true)
    }
}

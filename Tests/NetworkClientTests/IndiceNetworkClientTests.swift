import Testing
import Foundation
import OSLog
@testable import NetworkClient



@Suite("NetworkClient")
final class IndiceNetworkClientTests {
        
    
    @Test
    func osLoggerTest() async throws {
        struct Body: Codable {
            var valueString: String = "Hello World!"
            var valueInt: Int = 42
            var valueDouble: Double = 3.14159265358979323846
            var valueBool: Bool = true
            var valueDate: Date = Date()
            var valueData: Data = "Swift is awesome!".data(using: .utf8)!
        }
        
        let logger = DefaultLogger.default()
        let request = URLRequest.builder()
            .get(url: URL(string: "https://example.com/")!)
            // .bodyJson(of: Body())
            .build()
        
        let client = NetworkClient(logging: logger)
        
        try await client.fetch(request: request).item
    }
}

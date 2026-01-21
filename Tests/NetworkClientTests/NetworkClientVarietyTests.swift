import Testing
import Foundation
@testable import NetworkClient

@Suite("NetworkClient Variety")
struct NetworkClientVarietyTests {
    
    @Test
    func decodingStringResponse() async throws {
        let responser = MockResponseDecoder { "Hello" }
        
        let client = NetworkClient(decoder: responser)
        let response: NetworkClient.Response<String>
            = try await client.fetch(request: .example)
        
        #expect(response.item == "Hello")
    }

    
    @Test func `should decode null result`() async throws {
        let responser = MockResponseDecoder { nil as String? }
        
        let client = NetworkClient(decoder: responser)
        let response: NetworkClient.Response<String?>
            = try await client.fetch(request: .example)
        
        #expect(response.item == nil)
    }
    
    
    
    @Test
    func `interceptor should be called num of times`() async throws {
        actor CallFlag {
            private(set)
            var called: Int = 0
            
            func setCalled()  { called += 1 }
            func callCount() -> Int { called }
        }

        final class TestInterceptor: InterceptorProtocol {
            private let flag: CallFlag
            init(flag: CallFlag) { self.flag = flag }
            func process(_ request: URLRequest, next: @Sendable (URLRequest) async throws -> NetworkClient.ChainResult) async throws -> NetworkClient.ChainResult {
                await flag.setCalled()
                return try await next(request)
            }
        }

        
        let tries = [0, 1, 5, 10]
        
        for tryCount in tries {
            let flag = CallFlag()
            let interceptor = TestInterceptor(flag: flag)
            let client = NetworkClient(interceptors: [interceptor])
            
            await withTaskGroup { group in
                (0..<tryCount).forEach { _ in
                    group.addTask {
                        _ = try? await client.fetch(request: .example)
                    }
                }
            }
            
            #expect(await flag.callCount() == tryCount)
        }
    }

    @Test
    func `failure shuold throw error`() async throws {
        let client = NetworkClient(
            session: .failing,
            apiErrorMapper: .default)
        
        let request = URLRequest.example
        
        await #expect(throws: Error.self, "Should throw error") {
            _ = try await client.fetch(request: request)
        }
    }

    
    @Test
    func `request should cachce instansce`() async throws {
        let client = NetworkClient()
        let request = URLRequest.example.withInstanceCaching()
        async let first  = client.fetch(request: request)
        async let second = client.fetch(request: request)

        let (r1, r2) = try await (first, second)
        
        #expect(r1.httpResponse == r2.httpResponse)
    }
}

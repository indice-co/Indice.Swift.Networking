import Foundation
import Testing
import NetworkClient
import NetworkUtilities
import NetworkTestSupport

@Suite("Data fetch · interceptor chain", .timeLimit(.minutes(1)))
struct DataInterceptorTests {
    @Test func interceptorsWrapTheTransportInOrder() async throws {
        let trace = InterceptorTrace()
        let fixture = HTTPFixture(.init(body: #"{"value":1}"#))
        defer { fixture.close() }
        let client = fixture.client(interceptors: [TracingInterceptor("A", trace: trace), TracingInterceptor("B", trace: trace)])
        let _: NetworkResponse<TestPayload> = try await client.fetch(request: fixture.request())
        #expect(await trace.values == ["A:request", "B:request", "B:response", "A:response"])
        #expect(fixture.requests.first?.value(forHTTPHeaderField: "X-Order") == "AB")
    }

    @Test func retryRunsOnlyTheRemainingInterceptors() async throws {
        let trace = InterceptorTrace()
        let fixture = HTTPFixture { _, attempt in
            attempt == 1 ? .init(status: 401, body: "expired") : .init(body: #"{"value":2}"#)
        }
        defer { fixture.close() }
        let client = fixture.client(interceptors: [TracingInterceptor("A", trace: trace), RetryUnauthorized(),
                                                   TracingInterceptor("B", trace: trace)])
        let response: NetworkResponse<TestPayload> = try await client.fetch(request: fixture.request())
        #expect(response.item.value == 2)
        #expect(fixture.requests.count == 2)
        #expect(fixture.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer refreshed")
        #expect(await trace.values == ["A:request", "B:request", "B:error", "B:request", "B:response", "A:response"])
    }

    @Test func rejectionBeforeNextDoesNotStartANetworkRequest() async {
        let fixture = HTTPFixture(.init())
        defer { fixture.close() }
        await #expect(throws: ClientFixtureError.rejected) {
            let _: NetworkResponse<Void> = try await fixture.client(interceptors: [RejectingInterceptor()]).fetch(request: fixture.request())
        }
        #expect(fixture.requests.isEmpty)
    }
}

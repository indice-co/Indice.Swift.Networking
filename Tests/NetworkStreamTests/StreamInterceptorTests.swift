import Foundation
import Testing
import NetworkClient
import NetworkStream
import NetworkUtilities
import NetworkTestSupport

@Suite("SSE stream · shared interceptor chain", .timeLimit(.minutes(1)))
struct StreamInterceptorTests {
    @Test func theSameClientAndInterceptorsHandleDataAndStreams() async throws {
        let trace = InterceptorTrace()
        let fixture = HTTPFixture { request, _ in
            request.url?.path == "/stream" ? .sse("data: {\"value\":2}\n\n") : .init(body: #"{"value":1}"#)
        }
        defer { fixture.close() }
        let client = fixture.client(interceptors: [TracingInterceptor("A", trace: trace), TracingInterceptor("B", trace: trace)])
        let data: NetworkResponse<TestPayload> = try await client.fetch(request: fixture.request("/data"))
        let stream = try await client.openSSEStream(TestPayload.self, request: fixture.request("/stream"))
        defer { stream.item.cancel() }
        var iterator = stream.item.makeAsyncIterator()
        #expect(data.item.value == 1)
        #expect(try await iterator.next()?.data.value == 2)
        #expect(await trace.values == ["A:request", "B:request", "B:response", "A:response",
                                       "A:request", "B:request", "B:response", "A:response"])
        #expect(fixture.requests.map { $0.value(forHTTPHeaderField: "X-Order") } == ["AB", "AB"])
    }

    @Test func unauthorizedOpeningRetriesThroughTheDownstreamChain() async throws {
        let trace = InterceptorTrace()
        let fixture = HTTPFixture { _, attempt in
            attempt == 1 ? .init(status: 401, body: "expired") : .sse("data: {\"value\":2}\n\n")
        }
        defer { fixture.close() }
        let client = fixture.client(interceptors: [TracingInterceptor("A", trace: trace), RetryUnauthorized(),
                                                   TracingInterceptor("B", trace: trace)])
        let stream = try await client.openSSEStream(TestPayload.self, request: fixture.request())
        defer { stream.item.cancel() }
        var iterator = stream.item.makeAsyncIterator()
        #expect(try await iterator.next()?.data.value == 2)
        #expect(fixture.requests.count == 2)
        #expect(fixture.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer refreshed")
        #expect(await trace.values == ["A:request", "B:request", "B:error", "B:request", "B:response", "A:response"])
    }
}

import Foundation
import Testing
import NetworkClient
import NetworkUtilities
import NetworkTestSupport

@Suite("Data fetch · in-flight request sharing", .timeLimit(.minutes(1)))
struct RequestCachingTests {
    @Test func completedResponsesAreNotKeptAsAPersistentCache() async throws {
        let fixture = HTTPFixture { _, attempt in .init(body: "{\"value\":\(attempt)}") }
        defer { fixture.close() }
        let client = fixture.client()
        let request = fixture.request().withInstanceCaching()
        let first: NetworkResponse<TestPayload> = try await client.fetch(request: request)
        let second: NetworkResponse<TestPayload> = try await client.fetch(request: request)
        #expect(first.item.value == 1)
        #expect(second.item.value == 2)
        #expect(fixture.requests.count == 2)
        #expect(fixture.requests.allSatisfy { !$0.shouldCacheInstance && $0.instanceHash == nil })
    }

    @Test func failedRequestsAreRemovedFromTheCache() async throws {
        let fixture = HTTPFixture { _, attempt in
            attempt == 1 ? .init(status: 500) : .init(body: #"{"value":2}"#)
        }
        defer { fixture.close() }
        let client = fixture.client()
        let request = fixture.request().withInstanceCaching(customHash: "failed-operation")
        do {
            let _: NetworkResponse<TestPayload> = try await client.fetch(request: request)
            Issue.record("Expected first request to fail")
        } catch NetworkClient.Error.apiError { }
        let response: NetworkResponse<TestPayload> = try await client.fetch(request: request)
        #expect(response.item.value == 2)
        #expect(fixture.requests.count == 2)
    }

    @Test func simultaneousRequestsWithoutCachingRemainIndependent() async throws {
        let release = AsyncGate()
        let fixture = HTTPFixture { _, _ in
            try await release.wait()
            return .init(body: #"{"value":1}"#)
        }
        defer { fixture.close() }
        let client = fixture.client()
        let request = fixture.request()
        async let first: NetworkResponse<TestPayload> = client.fetch(request: request)
        async let second: NetworkResponse<TestPayload> = client.fetch(request: request)
        do {
            try await waitUntil { fixture.requests.count == 2 }
        } catch {
            await release.open()
            throw error
        }
        await release.open()
        _ = try await (first, second)
        #expect(fixture.requests.count == 2)
    }

    @Test func simultaneousCachedRequestsShareOneTransportOperation() async throws {
        let release = AsyncGate()
        let trace = InterceptorTrace()
        let fixture = HTTPFixture { _, _ in
            try await release.wait()
            return .init(body: #"{"value":1}"#)
        }
        defer { fixture.close() }
        let client = fixture.client(interceptors: [TracingInterceptor("A", trace: trace)])
        let request = fixture.request().withInstanceCaching(customHash: "shared-operation")
        async let first: NetworkResponse<TestPayload> = client.fetch(request: request)
        async let second: NetworkResponse<TestPayload> = client.fetch(request: request)
        do {
            try await waitUntil { fixture.requests.count >= 1 }
            // Keep the first response pending while both callers enter the client.
            try await Task.sleep(for: .milliseconds(50))
        } catch {
            await release.open()
            throw error
        }
        await release.open()
        let (a, b) = try await (first, second)
        #expect(a.item == b.item)
        #expect(fixture.requests.count == 1)
        #expect(await trace.values == ["A:request", "A:response"])
    }
}

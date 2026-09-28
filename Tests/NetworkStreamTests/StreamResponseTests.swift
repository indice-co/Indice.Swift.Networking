import Foundation
import Testing
import NetworkClient
import NetworkStream
import NetworkUtilities
import NetworkTestSupport

@Suite("SSE stream · opening and event delivery", .timeLimit(.minutes(1)))
struct StreamResponseTests {
    @Test func eventsDecodeInOrderWithMetadataAndRetryInSeconds() async throws {
        var stub = StubResponse.sse("id: 42\nevent: update\nretry: 1500\ndata: {\"value\":1}\n\ndata: {\"value\":2}\n\n")
        stub.headers = ["Content-Type": "Text/Event-Stream; charset=utf-8", "X-Stream": "yes"]
        let fixture = HTTPFixture(stub)
        defer { fixture.close() }
        let response = try await fixture.client().openSSEStream(TestPayload.self, request: fixture.request())
        defer { response.item.cancel() }
        var events: [ServerSentEvent<TestPayload>] = []
        for try await event in response.item { events.append(event) }
        #expect(events.map(\.data.value) == [1, 2])
        #expect(events.map(\.event) == ["update", "message"])
        #expect(events.map(\.id) == ["42", "42"])
        #expect(events.map(\.retry) == [1.5, 1.5])
        #expect(response["X-Stream"] == "yes")
    }

    @Test func streamRequestsSetAcceptAndRemoveInstanceCachingMetadata() async throws {
        let fixture = HTTPFixture(.sse("data: {\"value\":1}\n\n"))
        defer { fixture.close() }
        let request = fixture.request().withInstanceCaching(customHash: "not-a-stream-cache")
        let response = try await fixture.client().openSSEStream(TestPayload.self, request: request)
        response.item.cancel()
        let sent = try #require(fixture.requests.first)
        #expect(sent.value(forHTTPHeaderField: "Accept") == "text/event-stream")
        #expect(sent.cachePolicy == .reloadIgnoringLocalCacheData)
        #expect(!sent.shouldCacheInstance)
        #expect(sent.instanceHash == nil)
    }

    @Test func independentStreamsAreNotSharedEvenWhenCachingWasRequested() async throws {
        let fixture = HTTPFixture(.sse("data: {\"value\":1}\n\n", finishes: false))
        defer { fixture.close() }
        let client = fixture.client()
        let request = fixture.request().withInstanceCaching()
        async let first = client.openSSEStream(TestPayload.self, request: request)
        async let second = client.openSSEStream(TestPayload.self, request: request)
        let (a, b) = try await (first, second)
        defer { a.item.cancel(); b.item.cancel() }
        #expect(a.item !== b.item)
        #expect(fixture.requests.count == 2)
    }

    @Test func incompleteFinalEventIsDiscardedAtEOF() async throws {
        let fixture = HTTPFixture(.sse("data: {\"value\":1}\n\ndata: {\"value\":2}\n"))
        defer { fixture.close() }
        let response = try await fixture.client().openSSEStream(TestPayload.self, request: fixture.request())
        var iterator = response.item.makeAsyncIterator()
        #expect(try await iterator.next()?.data.value == 1)
        #expect(try await iterator.next() == nil)
    }
}

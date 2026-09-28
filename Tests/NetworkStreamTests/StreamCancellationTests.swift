import Foundation
import Testing
import NetworkClient
import NetworkStream
import NetworkTestSupport

@Suite("SSE stream · cancellation", .timeLimit(.minutes(1)))
struct StreamCancellationTests {
    @Test func explicitCancelClosesConnectionAndPreventsBufferedDelivery() async throws {
        let fixture = HTTPFixture(.sse("data: {\"value\":1}\n\n", finishes: false))
        defer { fixture.close() }
        let response = try await fixture.client().openSSEStream(TestPayload.self, request: fixture.request())
        var iterator = response.item.makeAsyncIterator()
        response.item.cancel()
        response.item.cancel()
        await #expect(throws: CancellationError.self) { try await iterator.next() }
        try await waitUntil { fixture.stoppedRequests > 0 }
    }

    @Test func cancellingAWaitingConsumerInterruptsTheRead() async throws {
        let fixture = HTTPFixture(.sse(": heartbeat\n", finishes: false))
        defer { fixture.close() }
        let response = try await fixture.client().openSSEStream(TestPayload.self, request: fixture.request())
        let started = AsyncGate()
        let consumer = Task {
            var iterator = response.item.makeAsyncIterator()
            await started.open()
            return try await iterator.next()
        }
        try await started.wait()
        consumer.cancel()
        do {
            _ = try await consumer.value
            Issue.record("Expected cancellation")
        } catch is CancellationError { }
        catch let error as URLError { #expect(error.code == .cancelled) }
        try await waitUntil { fixture.stoppedRequests > 0 }
    }

    @Test func alreadyCancelledOpeningDoesNotReachTheTransport() async throws {
        let fixture = HTTPFixture(.sse(""))
        defer { fixture.close() }
        let release = AsyncGate()
        let opening = Task {
            // The test cancels before this gate opens; ignoring its cancellation lets
            // openSSEStream itself demonstrate the entry cancellation check.
            try? await release.wait()
            return try await fixture.client().openSSEStream(TestPayload.self, request: fixture.request())
        }
        opening.cancel()
        await release.open()
        await #expect(throws: CancellationError.self) { try await opening.value }
        #expect(fixture.requests.isEmpty)
    }
}

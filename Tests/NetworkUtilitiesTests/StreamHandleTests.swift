import Foundation
import Testing
import NetworkUtilities
import NetworkTestSupport

@Suite("Stream handle · lifetime", .timeLimit(.minutes(1)))
struct StreamHandleTests {
    @Test func endOfSequenceTerminatesExactlyOnce() async throws {
        let elements = Locked([1, 2])
        let terminations = Locked(0)
        let handle = StreamHandle<Int>(next: {
            elements.withValue { $0.isEmpty ? nil : $0.removeFirst() }
        }, onTermination: { terminations.withValue { $0 += 1 } })
        var iterator = handle.makeAsyncIterator()
        #expect(try await iterator.next() == 1)
        #expect(try await iterator.next() == 2)
        #expect(try await iterator.next() == nil)
        #expect(try await iterator.next() == nil)
        handle.cancel()
        #expect(terminations.withValue { $0 } == 1)
    }

    @Test func readFailureTerminatesAndIsNotRepeated() async throws {
        let terminations = Locked(0)
        let handle = StreamHandle<Int>(next: { throw URLError(.networkConnectionLost) },
                                       onTermination: { terminations.withValue { $0 += 1 } })
        var iterator = handle.makeAsyncIterator()
        await #expect(throws: URLError(.networkConnectionLost)) { try await iterator.next() }
        #expect(try await iterator.next() == nil)
        #expect(terminations.withValue { $0 } == 1)
    }

    @Test func explicitCancellationPreventsFurtherDelivery() async {
        let reads = Locked(0)
        let terminations = Locked(0)
        let handle = StreamHandle<Int>(next: {
            reads.withValue { $0 += 1 }
            return 1
        }, onTermination: { terminations.withValue { $0 += 1 } })
        var iterator = handle.makeAsyncIterator()
        handle.cancel()
        handle.cancel()
        await #expect(throws: CancellationError.self) { try await iterator.next() }
        #expect(reads.withValue { $0 } == 0)
        #expect(terminations.withValue { $0 } == 1)
    }

    @Test func releasingAnUnusedHandleTerminatesIt() {
        let terminations = Locked(0)
        var handle: StreamHandle<Int>? = .init(next: { nil }, onTermination: { terminations.withValue { $0 += 1 } })
        #expect(handle != nil)
        handle = nil
        #expect(terminations.withValue { $0 } == 1)
    }

    @Test func cancellingTheConsumingTaskUnblocksTheRead() async throws {
        let reading = AsyncGate()
        let release = AsyncGate()
        let terminations = Locked(0)
        let handle = StreamHandle<Int>(next: {
            await reading.open()
            try await release.wait()
            return nil
        }, onTermination: {
            terminations.withValue { $0 += 1 }
            Task { await release.open() }
        })
        let consumer = Task {
            var iterator = handle.makeAsyncIterator()
            return try await iterator.next()
        }
        try await reading.wait()
        consumer.cancel()
        await #expect(throws: CancellationError.self) { try await consumer.value }
        #expect(terminations.withValue { $0 } == 1)
    }
}

import Foundation

/// A one-shot, cancellation-aware gate for holding a response until a test releases it.
package actor AsyncGate {
    private var opened = false
    private var waiters: [UUID: CheckedContinuation<Void, any Error>] = [:]

    package init() {}

    package func wait() async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            guard !opened else { return }
            try await withCheckedThrowingContinuation { waiters[id] = $0 }
        } onCancel: {
            Task { await self.cancel(id) }
        }
    }

    package func open() {
        opened = true
        let pending = waiters.values
        waiters.removeAll()
        for waiter in pending { waiter.resume() }
    }

    private func cancel(_ id: UUID) {
        waiters.removeValue(forKey: id)?.resume(throwing: CancellationError())
    }
}

package enum FixtureError: Error { case timedOut }

/// Poll only observable asynchronous state, with a deadline so regressions fail promptly.
package func waitUntil(
    _ condition: @Sendable () async -> Bool
) async throws {
    let deadline = ProcessInfo.processInfo.systemUptime + 3
    while !(await condition()) {
        guard ProcessInfo.processInfo.systemUptime < deadline else { throw FixtureError.timedOut }
        try await Task.sleep(nanoseconds: 5_000_000)
    }
}

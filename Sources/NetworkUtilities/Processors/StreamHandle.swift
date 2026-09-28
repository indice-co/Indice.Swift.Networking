//
//  StreamHandle.swift
//  NetworkClient
//
//  Created by Nikolas Konstantakopoulos on 28/9/26.
//

import Foundation


/// A single-consumer asynchronous sequence that owns a stream's lifetime.
///
/// Create exactly one iterator and consume it sequentially.
///
/// The supplied `next` operation must return:
/// - An element when one becomes available.
/// - `nil` when the stream finishes.
/// - An error when the stream fails.
///
/// `onTermination` must synchronously initiate cleanup and unblock any
/// pending `next` operation. It is called exactly once, on completion,
/// failure, cancellation, or release of the handle.
///
/// Breaking out of a loop does not itself terminate the stream.
/// Use `defer { stream.cancel() }` when consuming it.
public final class StreamHandle<Element: Sendable>: AsyncSequence, @unchecked Sendable {
    
    // Sendability:
    // - Operations are immutable @Sendable closures.
    // - Mutable lifecycle flags are protected by `lock`.
    // - One iterator is permitted; iteration must be sequential.

    private let readNext: @Sendable () async throws -> Element?
    private let onTermination: @Sendable () -> Void

    private let lock = NSLock()
    private var iteratorCreated = false
    private var terminated = false

    public init(
        next: @escaping @Sendable () async throws -> Element?,
        onTermination: @escaping @Sendable () -> Void
    ) {
        self.readNext = next
        self.onTermination = onTermination
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        // Retains the connection's owner throughout iteration.
        private let handle: StreamHandle<Element>
        private var finished = false

        fileprivate init(handle: StreamHandle<Element>) {
            self.handle = handle
        }

        public mutating func next() async throws -> Element? {
            guard !finished else { return nil }

            do {
                let element = try await handle.nextElement()

                if case nil = element {
                    finished = true
                    handle.cancel()
                }

                return element
            } catch {
                finished = true
                handle.cancel()
                throw error
            }
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        lock.withLock {
            precondition(
                !iteratorCreated,
                "StreamHandle supports exactly one iterator."
            )
            iteratorCreated = true
        }

        return AsyncIterator(handle: self)
    }

    /// Ends the stream and initiates cleanup. Safe to call repeatedly.
    public func cancel() {
        let shouldTerminate = lock.withLock {
            guard !terminated else { return false }
            terminated = true
            return true
        }

        // Invoke outside the lock: cleanup may call other synchronized code.
        if shouldTerminate {
            onTermination()
        }
    }

    private func checkTermination() throws {
        let isTerminated = lock.withLock { terminated }

        if isTerminated {
            throw CancellationError()
        }
    }

    private func nextElement() async throws -> Element? {
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try checkTermination()

            let element = try await readNext()

            try Task.checkCancellation()
            try checkTermination()

            return element
        } onCancel: {
            self.cancel()
        }
    }

    deinit {
        cancel()
    }
}

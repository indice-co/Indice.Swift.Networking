import Foundation

/// Test fixtures receive callbacks on URLSession queues as well as test tasks.
package final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    package init(_ value: Value) { self.value = value }

    @discardableResult
    package func withValue<Result>(_ operation: (inout Value) -> Result) -> Result {
        lock.withLock { operation(&value) }
    }
}

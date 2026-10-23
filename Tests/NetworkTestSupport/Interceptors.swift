import Foundation
import NetworkClient
import NetworkUtilities

package actor InterceptorTrace {
    private var entries: [String] = []
    package init() {}
    package func record(_ entry: String) { entries.append(entry) }
    package var values: [String] { entries }
}

/// An actor conformer also protects the chain's Sendable contract at compile time.
package actor TracingInterceptor: InterceptorProtocol {
    private let name: String
    private let trace: InterceptorTrace

    package init(_ name: String, trace: InterceptorTrace) {
        self.name = name
        self.trace = trace
    }

    package func process<T: Sendable>(
        _ request: URLRequest,
        next: @Sendable (URLRequest) async throws -> NetworkResponse<T>
    ) async throws -> NetworkResponse<T> {
        await trace.record("\(name):request")
        var request = request
        request.setValue((request.value(forHTTPHeaderField: "X-Order") ?? "") + name,
                         forHTTPHeaderField: "X-Order")
        do {
            let result = try await next(request)
            await trace.record("\(name):response")
            return result
        } catch {
            await trace.record("\(name):error")
            throw error
        }
    }
}

package struct RetryUnauthorized: InterceptorProtocol {
    package init() {}
    package func process<T: Sendable>(
        _ request: URLRequest,
        next: @Sendable (URLRequest) async throws -> NetworkResponse<T>
    ) async throws -> NetworkResponse<T> {
        do { return try await next(request) }
        catch let error as NetworkClient.Error where error.statusCode == 401 {
            var retry = request
            retry.setValue("Bearer refreshed", forHTTPHeaderField: "Authorization")
            return try await next(retry)
        }
    }
}

package struct TestPayload: Codable, Sendable, Equatable {
    package let value: Int
    package init(value: Int) { self.value = value }
}

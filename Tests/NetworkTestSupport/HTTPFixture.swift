import Foundation
import NetworkClient

package struct StubResponse: Sendable {
    package var status: Int = 200
    package var headers: [String: String] = ["Content-Type": "application/json"]
    package var chunks: [Data] = []
    package var finishes = true
    package var failure: URLError?
    package var isHTTP = true

    package init(
        status: Int = 200,
        headers: [String: String] = ["Content-Type": "application/json"],
        body: String = ""
    ) {
        self.status = status
        self.headers = headers
        chunks = body.isEmpty ? [] : [Data(body.utf8)]
    }

    package static func sse(_ body: String, finishes: Bool = true) -> Self {
        var result = Self(headers: ["Content-Type": "text/event-stream"], body: body)
        result.finishes = finishes
        return result
    }
}

/// Each fixture has its own host, session, handler and request history. Tests can run in parallel.
package final class HTTPFixture: Sendable {
    package typealias Handler = @Sendable (URLRequest, Int) async throws -> StubResponse

    private let host = UUID().uuidString.lowercased() + ".invalid"
    private let state: State
    package let session: URLSession

    package init(handler: @escaping Handler) {
        state = State(handler: handler)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)
        StubURLProtocol.registry.withValue { $0[host] = state }
    }

    package convenience init(_ response: StubResponse) {
        self.init { _, _ in response }
    }

    package var requests: [URLRequest] { state.requests.withValue { $0 } }
    package var stoppedRequests: Int { state.stopped.withValue { $0 } }

    package func request(_ path: String = "/resource") -> URLRequest {
        URLRequest(url: URL(string: "https://\(host)\(path)")!)
    }

    package func client(
        interceptors: [any InterceptorProtocol] = [],
        decoder: NetworkClient.Decoder = .default.handlingOptionalResponses,
        errorMapper: ResponseErrorMapper = .default
    ) -> NetworkClient {
        NetworkClient(
            interceptors: interceptors,
            decoder: decoder,
            transport: URLSessionTransport(session: session),
            apiErrorMapper: errorMapper
        )
    }

    package func close() {
        session.invalidateAndCancel()
        _ = StubURLProtocol.registry.withValue { $0.removeValue(forKey: host) }
    }

    deinit { close() }

    fileprivate final class State: Sendable {
        let handler: Handler
        let requests = Locked<[URLRequest]>([])
        let stopped = Locked(0)
        init(handler: @escaping Handler) { self.handler = handler }
    }
}

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    static let registry = Locked<[String: HTTPFixture.State]>([:])
    private let operation = Locked<Task<Void, Never>?>(nil)
    private let state = Locked<HTTPFixture.State?>(nil)

    // Catch every request, including unexpected hosts, so tests never fall through to the network.
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let fixture = Self.registry.withValue({ $0[request.url?.host ?? ""] }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        state.withValue { $0 = fixture }
        let attempt = fixture.requests.withValue {
            $0.append(request)
            return $0.count
        }
        operation.withValue { task in
            task = Task { @Sendable [self, fixture] in
                do {
                    let response = try await fixture.handler(request, attempt)
                    try Task.checkCancellation()
                    if response.isHTTP {
                        let http = HTTPURLResponse(url: request.url!, statusCode: response.status,
                                                   httpVersion: "HTTP/1.1", headerFields: response.headers)!
                        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
                    } else {
                        let other = URLResponse(url: request.url!, mimeType: nil,
                                                expectedContentLength: 0, textEncodingName: nil)
                        client?.urlProtocol(self, didReceive: other, cacheStoragePolicy: .notAllowed)
                    }
                    for chunk in response.chunks {
                        try Task.checkCancellation()
                        client?.urlProtocol(self, didLoad: chunk)
                    }
                    if let error = response.failure {
                        client?.urlProtocol(self, didFailWithError: error)
                    } else if response.finishes {
                        client?.urlProtocolDidFinishLoading(self)
                    }
                } catch is CancellationError {
                    // URLSession owns cancellation delivery once stopLoading has been called.
                } catch {
                    client?.urlProtocol(self, didFailWithError: error)
                }
            }
        }
    }

    override func stopLoading() {
        state.withValue { $0 }?.stopped.withValue { $0 += 1 }
        let task = operation.withValue { $0 }
        task?.cancel()
    }
}

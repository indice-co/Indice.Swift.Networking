import Foundation
import Testing
import NetworkClient
import NetworkUtilities
import NetworkTestSupport

@Suite("Data fetch · responses and decoding", .timeLimit(.minutes(1)))
struct DataFetchTests {
    @Test(arguments: [200, 201, 206])
    func successfulHTTPResponsesDecodeAndPreserveMetadata(_ status: Int) async throws {
        let fixture = HTTPFixture(.init(status: status, headers: ["X-Request-ID": "request-123"], body: #"{"value":42}"#))
        defer { fixture.close() }
        let response: NetworkResponse<TestPayload> = try await fixture.client().fetch(request: fixture.request())
        #expect(response.item == TestPayload(value: 42))
        #expect(response.httpResponse.statusCode == status)
        #expect(response["X-Request-ID"] == "request-123")
        #expect(fixture.requests.count == 1)
    }

    @Test func voidFetchAcceptsAnEmptyResponse() async throws {
        let fixture = HTTPFixture(.init(status: 204))
        defer { fixture.close() }
        let response: NetworkResponse<Void> = try await fixture.client().fetch(request: fixture.request())
        #expect(response.httpResponse.statusCode == 204)
    }

    @Test(arguments: ["", "null"])
    func optionalPayloadAcceptsEmptyAndJSONNull(_ body: String) async throws {
        let fixture = HTTPFixture(.init(body: body))
        defer { fixture.close() }
        let response: NetworkResponse<TestPayload?> = try await fixture.client().fetch(request: fixture.request())
        #expect(response.item == nil)
    }

    @Test func decodedModelsDoNotNeedToBeSendable() async throws {
        let fixture = HTTPFixture(.init(body: #"{"value":7}"#))
        defer { fixture.close() }
        let client: any RequestProcessor = fixture.client()
        let response: NetworkResponse<MutablePayload> = try await client.fetch(request: fixture.request())
        response.item.value = 8
        #expect(response.item.value == 8)
    }

    @Test func malformedJSONIsReportedAsADecodingError() async throws {
        let fixture = HTTPFixture(.init(body: #"{"value":"wrong type"}"#))
        defer { fixture.close() }
        do {
            let _: NetworkResponse<TestPayload> = try await fixture.client().fetch(request: fixture.request())
            Issue.record("Expected a decoding error")
        } catch NetworkClient.Error.decodingError(let error) {
            guard case .typeMismatch = error else { Issue.record("Expected type mismatch, got \(error)"); return }
        }
    }

    @Test func customDecoderErrorsArePreserved() async {
        let fixture = HTTPFixture(.init(body: "anything"))
        defer { fixture.close() }
        await #expect(throws: ClientFixtureError.decoded) {
            let _: NetworkResponse<TestPayload> = try await fixture.client(decoder: FailingDecoder()).fetch(request: fixture.request())
        }
    }
}

import Foundation
import Testing
import NetworkClient
import NetworkStream
import NetworkUtilities
import NetworkTestSupport

@Suite("SSE stream · opening and consumption failures", .timeLimit(.minutes(1)))
struct StreamFailureTests {
    @Test(arguments: ["application/json", "text/plain", ""])
    func nonSSEContentTypesFailDuringOpening(_ contentType: String) async throws {
        let headers = contentType.isEmpty ? [:] : ["Content-Type": contentType]
        let fixture = HTTPFixture(.init(headers: headers))
        defer { fixture.close() }
        do {
            _ = try await fixture.client().openSSEStream(TestPayload.self, request: fixture.request())
            Issue.record("Expected unexpectedContentType")
        } catch SSEError.unexpectedContentType(let actual) {
            #expect(actual == (contentType.isEmpty ? nil : contentType))
        }
    }

    @Test func httpErrorsPreserveDataBeforeContentTypeValidation() async throws {
        let body = #"{"message":"unauthorized"}"#
        let fixture = HTTPFixture(.init(status: 401, body: body))
        defer { fixture.close() }
        do {
            _ = try await fixture.client().openSSEStream(TestPayload.self, request: fixture.request())
            Issue.record("Expected HTTP error")
        } catch NetworkClient.Error.apiError(let response, let data) {
            #expect(response.statusCode == 401)
            #expect(data == Data(body.utf8))
        }
    }

    @Test func oversizedHTTPErrorBodyIsBounded() async throws {
        let fixture = HTTPFixture(.init(status: 500, body: String(repeating: "x", count: 70 * 1024)))
        defer { fixture.close() }
        do {
            _ = try await fixture.client().openSSEStream(TestPayload.self, request: fixture.request())
            Issue.record("Expected HTTP error")
        } catch NetworkClient.Error.apiError(_, let data) {
            #expect(data.count == 64 * 1024)
        }
    }

    @Test func decodingFailureOccursDuringConsumption() async throws {
        let fixture = HTTPFixture(.sse("data: not-json\n\n"))
        defer { fixture.close() }
        let response = try await fixture.client().openSSEStream(TestPayload.self, request: fixture.request())
        var iterator = response.item.makeAsyncIterator()
        do {
            _ = try await iterator.next()
            Issue.record("Expected decoding error")
        } catch NetworkClient.Error.decodingError { }
        #expect(try await iterator.next() == nil)
    }

    @Test func invalidUTF8IsDeliveredToTheConsumer() async throws {
        var stub = StubResponse.sse("")
        stub.chunks = [Data([0xFF, 10])]
        let fixture = HTTPFixture(stub)
        defer { fixture.close() }
        let response = try await fixture.client().openSSEStream(TestPayload.self, request: fixture.request())
        var iterator = response.item.makeAsyncIterator()
        do {
            _ = try await iterator.next()
            Issue.record("Expected invalidUTF8")
        } catch SSEError.invalidUTF8 { }
    }

    @Test func connectionFailureBeforeHeadersPropagates() async throws {
        let fixture = HTTPFixture { _, _ in throw URLError(.cannotConnectToHost) }
        defer { fixture.close() }
        do {
            _ = try await fixture.client().openSSEStream(TestPayload.self, request: fixture.request())
            Issue.record("Expected connection failure")
        } catch let error as URLError {
            #expect(error.code == .cannotConnectToHost)
        }
    }
}

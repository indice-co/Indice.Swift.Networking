import Foundation
import Testing
import NetworkClient
import NetworkUtilities
import NetworkTestSupport

@Suite("Data fetch · HTTP and transport failures", .timeLimit(.minutes(1)))
struct DataFailureTests {
    @Test(arguments: [400, 401, 403, 500])
    func httpErrorsPreserveStatusAndRawBody(_ status: Int) async throws {
        let body = #"{"message":"rejected"}"#
        let fixture = HTTPFixture(.init(status: status, body: body))
        defer { fixture.close() }
        do {
            let _: NetworkResponse<TestPayload> = try await fixture.client().fetch(request: fixture.request())
            Issue.record("Expected HTTP error")
        } catch NetworkClient.Error.apiError(let response, let data) {
            #expect(response.statusCode == status)
            #expect(data == Data(body.utf8))
        }
    }

    @Test func customErrorMapperReceivesTheResponseBody() async {
        let received = Locked<Data?>(nil)
        let fixture = HTTPFixture(.init(status: 409, body: "conflict"))
        defer { fixture.close() }
        let mapper = ResponseErrorMapper { info in
            received.withValue { $0 = info.data }
            return ClientFixtureError.mapped(info.response.statusCode)
        }
        await #expect(throws: ClientFixtureError.mapped(409)) {
            let _: NetworkResponse<Void> = try await fixture.client(errorMapper: mapper).fetch(request: fixture.request())
        }
        #expect(received.withValue { $0 } == Data("conflict".utf8))
    }

    @Test func transportFailureIsNotReportedAsAnHTTPError() async throws {
        let fixture = HTTPFixture { _, _ in throw URLError(.timedOut) }
        defer { fixture.close() }
        do {
            let _: NetworkResponse<Void> = try await fixture.client().fetch(request: fixture.request())
            Issue.record("Expected transport failure")
        } catch let error as URLError {
            #expect(error.code == .timedOut)
        }
    }

    @Test func nonHTTPResponseIsRejected() async throws {
        var response = StubResponse()
        response.isHTTP = false
        let fixture = HTTPFixture(response)
        defer { fixture.close() }
        do {
            let _: NetworkResponse<Void> = try await fixture.client().fetch(request: fixture.request())
            Issue.record("Expected invalidResponse")
        } catch NetworkClient.Error.invalidResponse { }
    }
}

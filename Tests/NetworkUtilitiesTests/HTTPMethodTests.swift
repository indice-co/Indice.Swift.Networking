import Foundation
import Testing
import NetworkUtilities

@Suite("URL builder · HTTP methods")
struct HTTPMethodTests {
    @Test(arguments: [URLRequest.HTTPMethod.get, .post, .put, .patch, .delete])
    func builderAndPropertyUseTheExpectedVerb(_ method: URLRequest.HTTPMethod) {
        let built: URLRequest
        switch method {
        case .get: built = .get(url: .utilityFixture).build()
        case .post: built = .post(url: .utilityFixture).noBody().build()
        case .put: built = .put(url: .utilityFixture).noBody().build()
        case .patch: built = .patch(url: .utilityFixture).noBody().build()
        case .delete: built = .delete(url: .utilityFixture).build()
        }
        #expect(built.httpMethod == method.rawValue)
        #expect(built.method == method)
        #expect(built.url == .utilityFixture)
        #expect(built.httpBody == nil)

        var request = URLRequest(url: .utilityFixture)
        request.method = method
        #expect(request.httpMethod == method.rawValue)
    }

    @Test func unsupportedMethodDoesNotMasqueradeAsASupportedVerb() {
        var request = URLRequest(url: .utilityFixture)
        request.httpMethod = "OPTIONS"
        #expect(request.method == nil)
    }
}

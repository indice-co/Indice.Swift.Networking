import Foundation
import Testing
import NetworkUtilities

@Suite("URL builder · headers")
struct HeaderTests {
    @Test func setReplacesWhereAddAppends() {
        let request = URLRequest.get(url: .utilityFixture)
            .add(header: .custom(name: "X-Value", value: "first"))
            .add(header: .custom(name: "X-Value", value: "second"))
            .build()
        #expect(request.value(forHTTPHeaderField: "X-Value") == "first,second")
        let replaced = request.setting(header: .custom(name: "x-value", value: "replacement"))
        #expect(replaced.value(forHTTPHeaderField: "X-Value") == "replacement")
        #expect(request.value(forHTTPHeaderField: "X-Value") == "first,second")
    }

    @Test func typedHeadersUseTheirHTTPNames() {
        let request = URLRequest.get(url: .utilityFixture).set(headers: [
            .authorization(auth: "Bearer token"), .accept(type: .eventStream),
            .content(type: .json), .language(value: "el-GR")
        ]).build()
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
        #expect(request.value(forHTTPHeaderField: "Accept") == "text/event-stream")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Accept-Language") == "el-GR")
    }

    @Test func cachingMetadataCanBeRemovedWithoutLosingOrdinaryHeaders() {
        let original = URLRequest(url: .utilityFixture).setting(header: .authorization(auth: "token"))
        let cached = original.withInstanceCaching(customHash: "request-key")
        #expect(cached.shouldCacheInstance)
        #expect(cached.instanceHash == "request-key")
        let cleared = cached.clearingInstanceCaching()
        #expect(!cleared.shouldCacheInstance)
        #expect(cleared.instanceHash == nil)
        #expect(cleared == original)
    }
}

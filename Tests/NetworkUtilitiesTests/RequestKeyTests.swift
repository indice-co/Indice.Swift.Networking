import Foundation
import Testing
import NetworkUtilities

// stableKey is an in-process identity for sharing requests, not a persisted digest.
@Suite("Request keys · equivalence and separation")
struct RequestKeyTests {
    @Test func repeatedCallsAndCopiesHaveTheSameKey() {
        let request = URLRequest(url: URL(string: "https://example.invalid/items?a=1&b=2")!)
        let copy = request
        #expect(request.stableKey() == request.stableKey())
        #expect(request.stableKey() == copy.stableKey())
        #expect(request.stableKey() == request.withInstanceCaching().stableKey())
    }

    @Test func queryOrderingAndHostCasingDoNotChangeIdentity() {
        let first = URLRequest(url: URL(string: "https://EXAMPLE.invalid/items?b=2&a=1&a=0")!)
        let second = URLRequest(url: URL(string: "https://example.invalid/items?a=0&b=2&a=1")!)
        #expect(first.stableKey() == second.stableKey())
    }

    @Test(arguments: ["https://example.invalid/other?a=1", "https://other.invalid/items?a=1",
                      "https://example.invalid:8443/items?a=1", "https://example.invalid/items?a=2"])
    func endpointAndQueryChangesProduceDifferentKeys(_ url: String) {
        let original = URLRequest(url: URL(string: "https://example.invalid/items?a=1")!)
        #expect(original.stableKey() != URLRequest(url: URL(string: url)!).stableKey())
    }

    @Test func methodAndBodyArePartOfTheIdentity() {
        let get = URLRequest(url: .utilityFixture)
        var post = get
        post.method = .post
        #expect(get.stableKey() != post.stableKey())
        var withBody = post
        withBody.httpBody = Data("first".utf8)
        #expect(post.stableKey() != withBody.stableKey())
        var changed = withBody
        changed.httpBody = Data("second".utf8)
        #expect(withBody.stableKey() != changed.stableKey())
    }

    @Test func encodedQuerySeparatorsCannotCollideWithSeparateItems() {
        let single = URLRequest(url: URL(string: "https://example.invalid/?a=x%26b%3Dy")!)
        let separate = URLRequest(url: URL(string: "https://example.invalid/?a=x&b=y")!)
        #expect(single.stableKey() != separate.stableKey())
    }
}

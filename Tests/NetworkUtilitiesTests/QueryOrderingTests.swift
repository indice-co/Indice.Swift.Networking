import Foundation
import Testing
import NetworkUtilities

@Suite("URL builder · query ordering and escaping")
struct QueryOrderingTests {
    @Test func additionsKeepTheirOrderAndDuplicateNames() {
        let items = [URLQueryItem(name: "z", value: "last"),
                     URLQueryItem(name: "a", value: "first"),
                     URLQueryItem(name: "z", value: "again")]
        let request = URLRequest.get(url: .utilityFixture).add(queryItems: items).build()
        #expect(request.queryItems == items)
    }

    @Test func replacementsRetainUnrelatedOriginalItems() {
        let url = URL(string: "https://example.invalid/?keep=1&replace=old&keep=2#section")!
        let request = URLRequest.get(url: url)
            .add(queryItems: [.init(name: "replace", value: "new"), .init(name: "added", value: "3")])
            .build()
        #expect(request.queryItems == [.init(name: "keep", value: "1"), .init(name: "keep", value: "2"),
                                       .init(name: "replace", value: "new"), .init(name: "added", value: "3")])
        #expect(request.url?.fragment == "section")
    }

    @Test func nilSingleValuesAreOmittedButExplicitFlagsArePreserved() {
        let request = URLRequest.get(url: .utilityFixture)
            .add(query: "omitted", value: nil)
            .add(queryItems: [.init(name: "flag", value: nil), .init(name: "empty", value: "")])
            .build()
        #expect(request.queryItems == [.init(name: "flag", value: nil), .init(name: "empty", value: "")])
    }

    @Test(arguments: ["Γεια 👋", "a&b=c", "two words", "100%", "a+b"])
    func reservedAndUnicodeValuesRoundTrip(_ value: String) {
        let request = URLRequest.get(url: .utilityFixture).add(query: "search", value: value).build()
        #expect(request.queryItems == [.init(name: "search", value: value)])
    }

    @Test func buildingTwiceDoesNotDuplicateQueries() {
        let builder = URLRequest.get(url: .utilityFixture).add(query: "page", value: "2")
        #expect(builder.build() == builder.build())
    }

    @Test func queryDictionaryDecodesValuesAndUsesLastDuplicate() {
        let url = URL(string: "https://example.invalid/?q=hello%20world&q=last%26value&empty=")!
        #expect(url.queryParameters == ["q": "last&value", "empty": ""])
        #expect(URL.utilityFixture.queryParameters == nil)
    }
}

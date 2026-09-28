import Foundation

extension URL {
    static let utilityFixture = URL(string: "https://example.invalid/resource")!
}

extension URLRequest {
    var queryItems: [URLQueryItem] {
        url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
    }
}

final class TemporaryFile {
    let url: URL
    init(data: Data) throws {
        url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try data.write(to: url)
    }
    deinit { try? FileManager.default.removeItem(at: url) }
}

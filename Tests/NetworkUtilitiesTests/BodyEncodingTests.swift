import Foundation
import Testing
import NetworkUtilities

@Suite("URL builder · body encoding")
struct BodyEncodingTests {
    private struct Payload: Codable, Equatable {
        let name: String
        let count: Int
    }

    @Test func jsonBodyRoundTripsAndSetsContentType() throws {
        let payload = Payload(name: "Γεια", count: 3)
        let request = try URLRequest.post(url: .utilityFixture).bodyJson(of: payload).build()
        let body = try #require(request.httpBody)
        #expect(try JSONDecoder().decode(Payload.self, from: body) == payload)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test func unencodableJSONUsesTheLibraryError() {
        #expect(throws: BodyEncodingError.self) {
            try URLRequest.post(url: .utilityFixture).bodyJson(of: Double.nan)
        }
    }

    @Test func formEncodingEscapesReservedValuesAndPreservesArrayOrder() throws {
        let body = try DefaultFormEncoder().encode(["tags": ["a&b", "c=d", "Γεια"]])
        #expect(String(decoding: body, as: UTF8.self) == "tags[]=a%26b&tags[]=c%3Dd&tags[]=%CE%93%CE%B5%CE%B9%CE%B1")
        let scalar = try DefaultFormEncoder().encode(["a+b": "x y&z=1"])
        #expect(String(decoding: scalar, as: UTF8.self) == "a%2Bb=x%20y%26z%3D1")
    }

    @Test(arguments: [false, true])
    func formBuilderSetsTheRequestedCharset(_ utf8: Bool) throws {
        let builder = URLRequest.post(url: .utilityFixture)
        let request = try (utf8 ? builder.bodyFormUTF8(params: ["key": "value"])
                                : builder.bodyForm(params: ["key": "value"])).build()
        #expect(request.httpBody == Data("key=value".utf8))
        #expect(request.value(forHTTPHeaderField: "Content-Type") ==
                "application/x-www-form-urlencoded" + (utf8 ? "; charset=utf-8" : ""))
    }

    @Test func multipartUsesOneBoundaryAndPreservesBinaryFileBytes() throws {
        let bytes = Data([0, 255, 13, 10, 42])
        let file = try TemporaryFile(data: bytes)
        let request = try URLRequest.post(url: .utilityFixture).bodyMultipart { builder in
            _ = try builder.add(key: "name", value: "sample").add(key: "file", file: .init(
                file: file.url, filename: "sample.bin", mimeType: .type(mimeType: "application/octet-stream")))
        }.build()
        let contentType = try #require(request.value(forHTTPHeaderField: "Content-Type"))
        let boundary = try #require(contentType.components(separatedBy: "boundary=").last)
        let body = try #require(request.httpBody)
        #expect(body.starts(with: Data("--\(boundary)\r\n".utf8)))
        #expect(body.range(of: Data("name=\"file\"; filename=\"sample.bin\"\r\nContent-Type: application/octet-stream\r\n\r\n".utf8)) != nil)
        #expect(body.range(of: bytes) != nil)
        #expect(body.suffix(Data("--\(boundary)--".utf8).count) == Data("--\(boundary)--".utf8))
    }

    @Test func missingMultipartFileThrows() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        #expect(throws: MultipartFormFilePart.Error.self) {
            try URLRequest.post(url: .utilityFixture).bodyMultipart { builder in
                _ = try builder.add(key: "file", file: missing)
            }
        }
    }
}

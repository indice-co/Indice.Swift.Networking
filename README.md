# Indice.Swift.Networking  ![alt text](icon/icon-64.png "Indice logo")
![Swift 6.2](https://img.shields.io/badge/swift-6.2-orange.svg)
![platform iOs 13](https://img.shields.io/badge/iOS-v13-blue.svg)
![platform macOs 10.15](https://img.shields.io/badge/macOS-v10.15-blueviolet.svg)

Lightweight Swift networking utilities: a small HTTP client, request builders, encoders/decoders and helpers used across iOS/macOS projects.

- Focus: simple URLRequest construction, common body encodings (JSON, form, multipart), request deduplication, error mapping and pluggable logging/decoding.

## Requirements

- Swift 6.2
- iOS 13+ / macOS 10.15+

## Installation

### Swift Package Manager

Add the package entry to your Package.swift or use Xcode's SPM UI:

```swift
.package(url: "https://github.com/indice-co/Indice.Swift.Networking", .upToNextMajor(from: "1.5.0"))
```

### Manual

Clone the repository and add the package as a local Swift package or copy the sources you need.

## Quick start

1) Build a URLRequest with the typed builder

```swift
import NetworkUtilities

let request = URLRequest.build()
    .get(url: URL(string: "https://api.example.com/items")!)
    .add(query: "page", value: "1")
    .set(header: .accept(type: .json))
    .build()
```

2) Send requests with NetworkClient

```swift
import NetworkClient

let client = NetworkClient()

struct Item: Decodable {
    let id: Int 
    let name: String 
}

Task {
    do {
        let response: NetworkClient.Response<[Item]> = try await client.fetch(request: request)
        let items = response.item
        
        print("Got items: \(items.count)")
    } catch {
        print("Request failed: \(error)")
    }
}
```

## Decoding and optional responses

- The default decoder is `DefaultDecoder` which uses JSON decoding and also handles plain `String` and `Bool` responses.
- Use `NullHandlingDecoder` (via `decoder.handlingOptionalResponses`) if the endpoint may return empty bodies (e.g. 204) for optional types.

Example:

```swift
let client = NetworkClient(decoder: DefaultDecoder().handlingOptionalResponses)
```

## Request body helpers

- JSON body: `bodyJson(of:)` uses a `JSONDataEncoder` (default: `DefaultJsonEncoder`).
- Form body: `bodyForm(params:)` and `bodyFormUtf8(params:)` use `DefaultFormEncoder`.
- Multipart: `bodyMultipart` accepts a builder to add string fields, data or file parts.

Example (JSON POST):

```swift
struct Payload: Encodable { let name: String }

let request = try URLRequest.build()
    .post(url: URL(string: "https://api.example.com/create")!)
    .bodyJson(of: Payload(name: "Alice"))
    .set(header: .content(type: .json))
    .build()
```

Example (multipart):

```swift
let request = try URLRequest.build()
    .post(url: URL(string: "https://api.example.com/upload")!)
    .bodyMultipart { builder in
        builder.add(
            key: "description", 
            value: "My file")
        
        try builder.add(
            key: "file", 
            file: .init(
                file: fileUrl, 
                filename: "photo.jpg", 
                mimeType: .auto()))
    }
    .build()
```

## Interceptors and logging

- `NetworkClient` accepts an array of `Interceptor` instances. A `LoggingInterceptor` is provided for request/response logging.

Example:

```swift
let client = NetworkClient(interceptors: [LoggingInterceptor(level: .debug)])
```

## Request de-duplication (instance caching)

- The client can deduplicate identical requests when desired. Call `withInstanceCaching(customHash:)` on a `URLRequest` to enable instance caching. See `URLRequest` extensions in sources for details.

## Error mapping

- By default the client throws `NetworkClient.Error.apiError(response:data:)` for non-2xx responses.
- Customize mapping by providing a `ResponseErrorMapper` to the `NetworkClient` initializer to convert server errors into domain-specific errors.

## Testing

Run tests with:

```bash
swift test
```

## Where to look in the codebase

- Client implementation: `Sources/NetworkClient/Client/NetworkClient.swift`
- Request builder: `Sources/NetworkUtilities/URLRequestBuilder.swift`
- Encoders: `Sources/NetworkUtilities/Encoding.swift`
- Decoders: `Sources/NetworkClient/Protocols/Decoding` (including `DefaultDecoder` and `NullHandlingDecoder`)
- Interceptors & logging: `Sources/NetworkClient/Helpers` and `Sources/NetworkClient/Protocols/Logging`

## Contributing

Contributions, bug reports and PRs are welcome. Follow the repository style and include tests for new behavior.

## License

This project is licensed under the terms in the LICENSE file.


# Indice.Swift.Networking  ![alt text](icon/icon-64.png "Indice logo")
![Swift 6.2](https://img.shields.io/badge/swift-6.2-orange.svg)
![platform iOs 13](https://img.shields.io/badge/iOS-v13-blue.svg)
![platform macOs 10.15](https://img.shields.io/badge/macOS-v10.15-blueviolet.svg)

Lightweight Swift networking utilities: a small HTTP client, request builders, encoders/decoders and helpers used across iOS/macOS projects.

- Network Utilities: Various URLRequest helpers, and builder.
- Network Client: HTTP client supporting Interceptor chaining, reqeuest/response logging, with default encoding & decoding.

## Requirements

- Swift 5.10
- iOS 13+ / macOS 10.15+

## Installation

### Swift Package Manager

Add the package entry to your Package.swift or use Xcode's SPM UI:

```swift
.package(url: "https://github.com/indice-co/Indice.Swift.Networking", .upToNextMajor(from: "1.5.1"))
```


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
        let response: NetworkClient.Response<[Item]> 
            = try await client.fetch(request: request)
            
        let items = response.item
        
        print("Got items: \(items.count)")
    } catch {
        print("Request failed: \(error)")
    }
}
```


## Network Utilities

### Request body helpers

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

### URLRequest Builder helper

The `URLRequest.Builder` (via `URLRequest.builder(with: options)`), guides the request creation. 
For example a GET request, doesn't use a body
```swift
let request = try URLRequest.builder()
    .get(url: URL(string: "https://api.example.com/upload")!)
    .bodyJson(of: Payload(name: "Alice")) // ❌ compiler error.
    .build()
```

The `URLRequest.Builder` will go through the following stages
- VERB
- BODY (when applicable)
- QUERY Params
- HEADERS

```swift
let requestGET = try URLRequest.builder()
    .get(url: URL(string: "https://api.example.com/upload")!)
    .add(query: "param1", value: "value1")
    .add(query: "param2", value: "value2")
    .add(header: .authorisation(auth: authToken))
    .build()

let requestPOST = try URLRequest.builder()
    .post(url: URL(string: "https://api.example.com/upload")!)
    .bodyJson(of: Payload(name: "Alice"))
    .add(query: "param", value: "value")
    .add(header: .authorisation(auth: authToken))
    .build()
```

The VERBs that support a request body (`PUT`, `POST`, `PATCH`), require a `body` step on their build chain.

To build one without a body, use the `.noBody()` option.

```swift
let requestPOST = try URLRequest.builder()
    .post(url: URL(string: "https://api.example.com/upload")!)
    .noBody()
    .add(query: "param", value: "value")
    .build()
```



## Network Client

### Decoding and optional responses

- The default decoder is `DefaultDecoder` which uses JSON decoding and also handles plain `String` and `Bool` responses.
- Use `NullHandlingDecoder` (via `decoder.handlingOptionalResponses`) if the endpoint may return empty bodies (e.g. 204) for optional types.

Example:

These scenarios will **fail** throwing a `NetworkClient.Error.decodingError` error.

```swift
let client = NetworkClient(decoder: .default)

// Throws because the expected response is a not null model
// an empty body, Data(), will no t be decoded to SomeModel
let response: NetworkClient.Response<SomeModel> 
    try await client.fetch(request: request)


// Throws because while the model is nullable, 
// the default decoder will still try to decode an empty response body.
let response: NetworkClient.Response<SomeModel?> 
    try await client.fetch(request: request)




let clientWithNullDecoder = NetworkClient(decoder: .default.handlingOptionalResponses)

// Throws, while using the `NullHandlingDecoder`, the response is not a nullable model, 
// so the `Decode` will still try to decode an empty response body.
let response: NetworkClient.Response<SomeModel> 
    try await clientWithNullDecoder.fetch(request: request)

```

In order to use the `NullHandlingDecoder`, the response type MUST be an `Optional` type.
Only then will the decoder check the response body length.

```swift

let clientWithNullDecoder = NetworkClient(
    decoder: .default.handlingOptionalResponses)

// This will succeed with a null `reponse.item`
let response: NetworkClient.Response<SomeModel?> 
    try await clientWithNullDecoder.fetch(request: request)

```


### Interceptors and logging

- `NetworkClient` accepts an array of `Interceptor` instances. Interceptors can modify and react to requests and responses.
Interceptors are called in the order that are provided when building the `NetworkClient`. 

Example — adding an auth header

```swift
// Simple interceptor that adds an Authorization header
struct AuthInterceptor: InterceptorProtocol {
    let tokenStorage: TokenStorage

    func process(
        _ request: URLRequest,
        next: @Sendable (URLRequest) async throws -> NetworkClient.ChainResult
    ) async throws -> NetworkClient.ChainResult {
        let accessToken = try tokenStorage.requireAuthorization
        
        let authorizedRequest = request
            .setting(header: .authorisation(auth: accessToken))

        return try await next(authorizedRequest)
    }
}

let client = NetworkClient(interceptors: [AuthInterceptor(tokenStorage: someStorage)])
```

### Request de-duplication (instance caching)


- The client can deduplicate identical requests when desired. Call `withInstanceCaching()` on a `URLRequest` to enable instance caching.

Example — deduplicating two concurrent fetches for the same request:

```swift
import NetworkClient
import NetworkUtilities

struct Item: Decodable { let id: Int; let name: String }

let client = NetworkClient()

let request = URLRequest.build()
    .get(url: URL(string: "https://api.example.com/items")!)
    .set(header: .accept(type: .json))
    .build()
    .withInstanceCaching()

Task {
    async let first: NetworkClient.Response<[Item]> = try client.fetch(request: request)
    async let second: NetworkClient.Response<[Item]> = try client.fetch(request: request)

    do {
        let (r1, r2) = try await (first, second)
        print("Both responses received; items: \(r1.item.count), \(r2.item.count)")
    } catch {
        print("Request failed: \(error)")
    }
}
```

When `withInstanceCaching()` is used the client will perform a single network call for identical requests and return the same response to all awaiting callers.

Note: the instance cache only holds the in-flight task for the original request — the cache entry is removed when that request completes (either success or failure). A subsequent identical request made after completion will start a new HTTP call.



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


# NetworkUtilities

Small collection of helpers used by `NetworkClient` for building requests and handling common URL/HTTP utilities.

Contents:
- `Encoding.swift` — JSON and form encoders used to produce request bodies.
- `MimeType.swift` — infers MIME type for local files.
- `Params.swift` — convenient `Params` typealias and helpers for URL/form conversion.
- `URLExtensions.swift` — URL query helpers and URL encoding CharacterSet.
- `URLRequestBuilder.swift` — fluent builder for `URLRequest` (methods, headers, body, multipart).
- `URLRequestExtensions.swift` — convenience static helpers to start building requests.
- `URLRequestProperties.swift` — header/content types and helper methods on `URLRequest`.

Usage examples
-------------

Build a JSON POST request:

```
let request = try URLRequest.post(url: myURL)
    .bodyJson(of: myEncodable)
    .add(header: .authorisation(auth: "Bearer token"))
    .build()
```

Create a multipart upload:

```
let request = try URLRequest.post(url: myURL)
    .bodyMultipart { multipart in
        multipart.add(
            key: "file", 
            file: .init(
                file: fileURL, 
                filename: "photo.jpg", 
                mimeType: .auto()))
    }
    .build()
```

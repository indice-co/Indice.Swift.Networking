# Changelog

## [1.5.0] - 2025-12-04

### News
- Update swift-tools to 6.2

### Changes
- Add `URLRequest.builder(options:)` to override the default encoders used to generate the `URLRequest.httpBody`.
- Add `set(header:)` & `set(headers:)` on `URLRequest.HeaderBuilder` 
- `LogStream` is now a protocol.
- `DefaultLogger` uses a `LogStream` to insert log messages
- `DefaultLogger` minor changes to its messages representation.


### Breaking Changes
- `NetworkClient` used to cache a task for a `URLRequest`, returning the same active task isntance's value for the same request.
  This behavior now has to be opted-in, using the extension `URLRequest.withInstanceCaching()`.
- Minumum OSs bumped to iOS 14, macOS 11.
- Conformance to Swift6 strict concurrency cause changes to various signatures and definitions. 
- `NetworClient.Interceptor` renamed `process(_:completion:)` to `process(_:next:)` to better imply the chain process. 



## [1.4.2] - 2024-09-26

### Changes
- `NetworkClient` also logs any error data on a failed request.


## [1.4.1] - 2024-09-16

### Changes
- Exposed an `outputStream` on `DefaultLogger` to override the default logging target.

### Fixes
- `HeaderMasks` work properly


## [1.4.0] - 2024-08-30

### Changees
- Deprecate `URLRequest.MethodBuilder` *verb*(path:) methods. Use the relevant *verb*(url:).

### News
- `URLRequest.BodyBuilder` to create MultipartForm requests.
- `ResponseErrorMapper` can be injected to replace the default `NetworkClient.Error`, thrown from a faulty status code, with a consumer generated one.

### Breaking Changes
- Rename to package to `NetworkClient`.<br>
  Change your `import IndiceNetworkClient` to `import NetworkClient`.
- Split into two targets `NetworkClient` and `NetworkUtilities`.<br>
  The later contains any `URLRequest` and `URLRequest.Builder` related extension.
- Removal of `APIError` definition. Replaced with `NetworkClient.Error`. <br>
  To define a concrete Error type throw by your API, @see `ResponseErrorMapper`.
- Removal of `NetworkClient`'s custom headers, as the functionality can be achieved by a `NetworkClient.Interceptor`
- Replace `URLRequest.ContentType.urlUtf8`, with `URLRequest.ContentType.url(useUTF8Charset:)`.  


## [1.3.0] - 2024-06-07

### Fixes
- Bug where interceptors didn't correctly catch `APIError`s.


### Breaking Changes
-  Removal of the `NetworkClient.Retrier` class, as the functionality can be achieved by a `NetworkClient.Interceptor`.


## [v < 1.3.0] - Well...
We'll get to filling this space.

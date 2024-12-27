# Changelog


## [1.4.2] - 2024 - 09 - 26

### Changes
- `NetworkClient` also logs any error data on a failed request.


## [1.4.1] - 2024 - 09 - 16

### Changes
- Expose writing stream on `DefaultLogger`
- `HeaderMask` check fix when logging 


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

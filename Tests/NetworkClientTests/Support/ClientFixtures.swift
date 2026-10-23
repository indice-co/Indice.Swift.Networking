import Foundation
import NetworkClient
import NetworkUtilities

final class MutablePayload: Decodable {
    var value: Int
}

enum ClientFixtureError: Error, Equatable {
    case decoded
    case mapped(Int)
    case rejected
}

struct FailingDecoder: DecoderProtocol, Sendable {
    func decode<T: Decodable>(data: Data) throws -> T { throw ClientFixtureError.decoded }
}

struct RejectingInterceptor: InterceptorProtocol {
    func process<T: Sendable>(
        _ request: URLRequest,
        next: @Sendable (URLRequest) async throws -> NetworkResponse<T>
    ) async throws -> NetworkResponse<T> {
        throw ClientFixtureError.rejected
    }
}

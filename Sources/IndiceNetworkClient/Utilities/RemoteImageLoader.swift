//
//  RemoteImageLoader.swift
//  EVPulse
//
//  Created by Makis Stavropoulos on 17/1/22.
//

import Foundation

actor RemoteImageLoader {
    static let shared = RemoteImageLoader()

    private init() {}

    private var dataCache: [URLRequest: LoaderStatus] = [:]

    public func fetch(_ url: URL) async throws -> Data {
        let request = URLRequest(url: url)
        return try await fetch(request)
    }

    public func fetch(_ urlRequest: URLRequest) async throws -> Data {
        if let status = dataCache[urlRequest] {
            switch status {
            case .fetched(let data):
                return data
            case .inProgress(let task):
                return try await task.value
            }
        }

        let task: Task<Data, Error> = Task {
            let (data, _): (Data, URLResponse) = try await {
                if #available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *) {
                    return try await URLSession.shared.data(for: urlRequest)
                } else {
                    return try await URLSession.shared.asyncData(from: urlRequest)
                }
            }()
            
            print("******** Fetch data for image from URL: \(urlRequest)")
            return data
        }

        dataCache[urlRequest] = .inProgress(task)

        let data = try await task.value

        dataCache[urlRequest] = .fetched(data)

        return data
    }

    private enum LoaderStatus {
        case inProgress(Task<Data, Error>)
        case fetched(Data)
    }
}



#if canImport(UIKit)
import UIKit

extension RemoteImageLoader {
    public func fetch(_ url: URL) async throws -> UIImage {
        let data: Data = try await fetch(url)
        return UIImage(data: data)!
    }
    
    public func fetch(_ urlRequest: URLRequest) async throws -> UIImage {
        let data: Data = try await fetch(urlRequest)
        return UIImage(data: data)!
    }
}
#endif

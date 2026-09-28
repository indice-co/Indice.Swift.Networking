//
//  URLSessionExtensions.swift
//  
//
//  Created by Nikolas Konstantakopoulos on 10/2/22.
//

import Foundation

@available(iOS, deprecated: 15.0, message: "Use the built-in API instead 'data(for:)'")
public extension URLSession {
    func asyncData(from request: URLRequest) async throws -> (Data, URLResponse) {
        let taskBox = URLSessionTaskBox()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let task = self.dataTask(with: request) { data, response, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let data, let response else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                        return
                    }

                    continuation.resume(returning: (data, response))
                }

                taskBox.set(task)
                task.resume()
            }
        } onCancel: {
            taskBox.cancel()
        }
    }
}


private final class URLSessionTaskBox: @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionDataTask?
    private var cancelled = false

    func set(_ task: URLSessionDataTask) {
        lock.lock()
        if cancelled {
            lock.unlock()
            task.cancel()
            return
        }

        self.task = task
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let task = task
        lock.unlock()

        task?.cancel()
    }
}

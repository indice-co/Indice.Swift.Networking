//
//  DefaultLogger.swift
//  NetworkClient
//
//  Created by Nikolas Konstantakopoulos on 4/11/25.
//

import Foundation

public final class DefaultLogger: NetworkLogger, Sendable {
    
    public static var defaultTag: String { "Network Logger" }
    
    public let tag: String
    public let requestLevel  : NetworkLoggingLevel
    public let responseLevel : NetworkLoggingLevel
    
    private let logStream   : LogStream
    private let loggerFilter: LoggerFilter
    private let expectedType: String?
    private let headerMasks : [HeaderMasks]
    
    init(tag: String   = defaultTag,
         logStream     : LogStream,
         logFilter     : LoggerFilter = .always,
         requestLevel  : NetworkLoggingLevel = .full,
         responseLevel : NetworkLoggingLevel = .full,
         headerMasks   : [HeaderMasks] = [],
         expectedType  : String? = "application/json") {
        self.tag = tag
        self.logStream     = logStream
        self.loggerFilter  = logFilter
        self.expectedType  = expectedType
        self.headerMasks   = headerMasks
        self.requestLevel  = requestLevel
        self.responseLevel = responseLevel
    }
    
    private func canPrint(for type: NetworkLoggingType) -> Bool {
        (type == .request ? requestLevel : responseLevel) != .off
    }
    
    private func createMessage(from messages: [String]) -> String {
        messages
            .map { tag + ":: " + $0 }
            .joined(separator: "\n")
    }
    
    private func write(body: Data?, ofType contentType: String?, on messages: inout [String]) {
        guard let body else { return }
        
        func defaultPrintBody() {
            if let bodyString = String(data: body, encoding: .utf8) {
                messages.append("--- Body: Unhandled Content Type (\(String(describing: contentType)))")
                messages.append("--- Body: \(bodyString)")
            }
            return
        }
        
        guard let cType = contentType else {
            defaultPrintBody()
            return
        }
        
        func isContentType(_ type: URLRequest.ContentType) -> Bool {
            if cType.contains(type.value) {
                messages.append("--- Body: Content-Type \(cType)")
                return true
            }
            
            return false
        }
        
        if isContentType(.json) {
            if let json = try? JSONSerialization.jsonObject(with: body, options: []),
               let jsonData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
               let body = String(data: jsonData, encoding: .utf8) {
                body.split(whereSeparator: \.isNewline).forEach {
                    messages.append("--- Body: \($0)")
                }
                
                return
            }
        }
        
        if isContentType(.url()) {
            if let body = String(data: body, encoding: .utf8) {
                body.components(separatedBy: "&").forEach {
                    messages.append("--- Body: \($0)")
                }
            }
            return
        }
        
        defaultPrintBody()
    }
    
    public func log(request: URLRequest, type: LogType) {
        guard canPrint(for: .request) else { return }
        var messages: [String] = []
        
        let filterLevel = loggerFilter.acceptLoggingLevel(for: request)
        
        if requestLevel.contains(.status), filterLevel.contains(.status) {
            let prefix = request.method?.rawValue.uppercased() ?? "URL"
            
            if let url = request.url?.absoluteString {
                messages.append("--- \(prefix): \(url)")
            }
        }
        
        if requestLevel.contains(.headers), filterLevel.contains(.headers) {
            appendMessagesFor(headers: request.allHTTPHeaderFields, to: &messages)
        }
        
        if requestLevel.contains(.body), filterLevel.contains(.body) {
            let contentType = request.allHTTPHeaderFields?["Content-Type"] ?? expectedType
            write(body: request.httpBody, ofType: contentType, on: &messages)
        }
        
        guard !messages.isEmpty else { return }
        
        messages.insert("START --->", at: 0)
        messages.append("END ----->")
        
        log(messages, for: .request, type: type)
    }
    
    public func log(response: HTTPURLResponse, with data: Data?, type: LogType) {
        guard canPrint(for: .response) else { return }
        
        let filterLevel = loggerFilter.acceptLoggingLevel(for: response)
        
        var messages: [String] = []
        
        if responseLevel.contains(.status), filterLevel.contains(.status) {
            if let url = response.url?.absoluteString {
                messages.append("--- URL: \(url)")
            }
            
            messages.append("--- Status: \(response.statusCode)")
        }
        
        if responseLevel.contains(.headers), filterLevel.contains(.headers) {
            appendMessagesFor(headers: response.allHeaderFields, to: &messages)
        }
        
        if responseLevel.contains(.body), filterLevel.contains(.body) {
            let contentType = response.value(forHTTPHeaderField: "Content-Type") ?? expectedType
            write(body: data, ofType: contentType, on: &messages)
        }
        
        
        guard !messages.isEmpty else { return }
        
        
        messages.insert("START <---", at: 0)
        messages.append("END <-----")
        
        log(messages, for: .response, type: type)
    }
    
    public func log(_ message: String, for networkType: NetworkLoggingType, type: LogType) {
        guard canPrint(for: networkType) else { return }
        log([message], for: networkType, type: type)
    }
    
    public func log(_ messages: [String], for networkType: NetworkLoggingType, type: LogType) {
        guard canPrint(for: networkType) else { return }
        let message = createMessage(from: messages)
        logStream.log(message, for: type)
        
        logStream.log("\n")
    }
    
}


// MARK: - Helpers

private extension DefaultLogger {
    
    func transformed(value: String, forKey key: String) -> String {
        if let mask = headerMasks.first(where: { $0.shouldMask(key: key) }) {
            return switch mask.transformation {
            case .none: HeaderMasks.defaultTransformation(value)
            case .some(let transformation): transformation(value)
            }
        }
        
        return value
    }
    
    func appendMessagesFor(headers: [AnyHashable: Any]?, to messages: inout [String]) {
        messages.append(contentsOf: ["--- Headers: ---"])
        messages.append(contentsOf: (headers ?? [:]).map { key, value in
            let keyString = "\(key)"
            let valString = "\(value)"
            let transform = transformed(value:  valString, forKey: keyString)
            
            return "\(key): \(transform)"
        })
    }
    
}


public extension NetworkLogger where Self == DefaultLogger {
    
    static func `default`(requestLevel: NetworkLoggingLevel  = .full,
                          responseLevel: NetworkLoggingLevel = .full,
                          headerMasks: [HeaderMasks] = [],
                          logFilter: LoggerFilter = .always,
                          logStream: LogStream = .default) -> NetworkLogger {
        DefaultLogger(
            logStream: logStream,
            logFilter: logFilter,
            requestLevel: requestLevel,
            responseLevel: responseLevel,
            headerMasks: headerMasks)
    }
    
    static func `default`(logLevel: NetworkLoggingLevel = .full,
                          headerMasks: [HeaderMasks] = [],
                          logFilter: LoggerFilter = .always,
                          logStream: LogStream = .default) -> NetworkLogger {
        Self.default(
            requestLevel: logLevel,
            responseLevel: logLevel,
            headerMasks: headerMasks,
            logFilter: logFilter,
            logStream: logStream)
    }
    
    static var `default`: NetworkLogger { Self.default(logLevel: .full) }
    
}

//
//  LoggerProtocol.swift
//  
//
//  Created by Nikolas Konstantakopoulos on 14/2/22.
//

import Foundation
import NetworkUtilities

public struct NetworkLoggingLevel: OptionSet, Sendable {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let off     = NetworkLoggingLevel([])
    public static let status  = NetworkLoggingLevel(rawValue: 1 << 1)
    public static let headers = NetworkLoggingLevel(rawValue: 1 << 2)
    public static let body    = NetworkLoggingLevel(rawValue: 1 << 3)
    public static let full    : NetworkLoggingLevel = [.status, .headers, .body]
}

public enum NetworkLoggingType {
    case request, response
}

public protocol NetworkLogger: AnyObject, Sendable {
    var tag           : String { get }
    var requestLevel  : NetworkLoggingLevel { get }
    var responseLevel : NetworkLoggingLevel { get }
    
    func log(_ message  :  String,  for: NetworkLoggingType)
    func log(_ messages : [String], for: NetworkLoggingType)
    func log(request    : URLRequest)
    func log(response   : HTTPURLResponse, with: Data?)
}

public enum HeaderMasks: Sendable {
    case has(name: String)
    case contains(name: String)
    
    static let authorization: HeaderMasks = .has(name: "Authorization")
    
    fileprivate func shouldMask(key: String) -> Bool {
        switch self {
        case .contains(let name): key.contains(name)
        case .has     (let name): key == name
        }
    }
}

public class DefaultLogger: NetworkLogger, @unchecked Sendable {
    
    public static let defaultTag = "Network Logger"
    
    nonisolated(unsafe)
    public static let defaultStream = { (value: String) -> () in print(value) }
    
    public let tag: String
    public let requestLevel  : NetworkLoggingLevel
    public let responseLevel : NetworkLoggingLevel
    
    private let logStream: (String) -> ()
    private let expectedType: String?
    private let headerMasks: [HeaderMasks]
    
    init(tag: String   = defaultTag,
         logStream     : @escaping (String) -> () = DefaultLogger.defaultStream,
         requestLevel  : NetworkLoggingLevel = .full,
         responseLevel : NetworkLoggingLevel = .full,
         headerMasks   : [HeaderMasks] = [],
         expectedType  : String? = "application/json") {
        self.tag = tag
        self.logStream     = logStream
        self.expectedType  = expectedType
        self.headerMasks   = headerMasks
        self.requestLevel  = requestLevel
        self.responseLevel = responseLevel
    }
    
    private func canPrint(for type: NetworkLoggingType) -> Bool {
        (type == .request ? requestLevel : responseLevel) != .off
    }
    
    private func createMessage(from messages: [String]) -> [String] {
        messages.map { tag + ":: " + $0 }
    }
    
    private func log(body: Data?, ofType contentType: String?, on messages: inout [String]) {
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
            if let body = try? JSONSerialization.jsonObject(with: body, options: []) {
                "\(body)".split(whereSeparator: \.isNewline).forEach {
                    messages.append("--- Body: \($0)")
                }
            }
            return
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
    
    public func log(request: URLRequest) {
        guard canPrint(for: .request) else { return }
        var messages = ["START --->"]
        
        if requestLevel.contains(.status) {
            let prefix = request.method?.rawValue.uppercased() ?? "URL"
            
            if let url = request.url?.absoluteString {
                messages.append("--- \(prefix): \(url)")
            }
        }
        
        if requestLevel.contains(.headers) {
            appendMessagesFor(headers: request.allHTTPHeaderFields, to: &messages)
        }
        
        if requestLevel.contains(.body) {
            let contentType = request.allHTTPHeaderFields?["Content-Type"] ?? expectedType
            log(body: request.httpBody, ofType: contentType, on: &messages)
        }
        
        messages.append("END ----->")
        
        log(messages, for: .request)
    }
    
    public func log(response: HTTPURLResponse, with data: Data?) {
        guard canPrint(for: .response) else { return }
        
        var messages = ["START <---"]
        
        if responseLevel.contains(.status) {
            if let url = response.url?.absoluteString {
                messages.append("--- URL: \(url)")
            }
            
            messages.append("--- Status: \(response.statusCode)")
        }
        
        if responseLevel.contains(.headers) {
            appendMessagesFor(headers: response.allHeaderFields, to: &messages)
        }
        
        if responseLevel.contains(.body) {
            let contentType = response.value(forHTTPHeaderField: "Content-Type") ?? expectedType
            log(body: data, ofType: contentType, on: &messages)
        }
        
        messages.append("END <-----")
        
        log(messages, for: .response)
    }
    
    public func log(_ message: String, for type: NetworkLoggingType) {
        guard canPrint(for: type) else { return }
        log([message], for: type)
    }
    
    public func log(_ messages: [String], for type: NetworkLoggingType) {
        guard canPrint(for: type) else { return }
        createMessage(from: messages)
            .forEach(logStream)
        
        logStream("\n")
    }
    
}


// MARK: - Helpers

private extension DefaultLogger {
    
    func transformed(value: String, forKey key: String) -> String {
        if headerMasks.contains(where: { $0.shouldMask(key: key) }) {
            return String(repeating: "*", count: min(20, value.count))
        }
        
        return value
    }
    
    func appendMessagesFor(headers: [AnyHashable: Any]?, to messages: inout [String]) {
        messages.append(contentsOf: (headers ?? [:]).map { key, value in
            let keyString = "\(key)"
            let valString = "\(value)"
            let transform = transformed(value:  valString, forKey: keyString)
            
            return "--- Header: \(key): \(transform)"
        })
    }
    
}


public extension NetworkLogger where Self == DefaultLogger {
    
    static func `default`(requestLevel: NetworkLoggingLevel  = .full,
                          responseLevel: NetworkLoggingLevel = .full,
                          headerMasks: [HeaderMasks] = [],
                          logStream: @escaping (String) -> () = DefaultLogger.defaultStream) -> NetworkLogger {
        DefaultLogger(logStream: logStream,
                      requestLevel: requestLevel,
                      responseLevel: responseLevel,
                      headerMasks: headerMasks)
    }
    
    static func `default`(logLevel: NetworkLoggingLevel = .full,
                          headerMasks: [HeaderMasks] = [],
                          logStream:  @escaping (String) -> () = DefaultLogger.defaultStream) -> NetworkLogger {
        `default`(requestLevel: logLevel, responseLevel: logLevel, headerMasks: headerMasks, logStream: logStream)
    }
    
    static var `default`: NetworkLogger { `default`(logLevel: .full) }
    
}



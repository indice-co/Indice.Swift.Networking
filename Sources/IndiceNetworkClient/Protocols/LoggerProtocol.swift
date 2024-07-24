//
//  LoggerProtocol.swift
//  EVPulse
//
//  Created by Nikolas Konstantakopoulos on 14/2/22.
//

import Foundation

public struct NetworkLoggingLevel: OptionSet {
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

public protocol NetworkLogger {
    var tag   : String { get set }
    var requestLevel  : NetworkLoggingLevel { get set }
    var responseLevel : NetworkLoggingLevel { get set }
    
    func log(_ message  :  String,  for: NetworkLoggingType)
    func log(_ messages : [String], for: NetworkLoggingType)
    func log(request  : URLRequest)
    func log(response : HTTPURLResponse, with: Data?)
}


public class DefaultLogger: NetworkLogger {
    
    public static let defaultTag = "Network Logger"
    
    public var tag: String
    public var requestLevel  : NetworkLoggingLevel
    public var responseLevel : NetworkLoggingLevel
    
    private var expectedType: String?
    
    init(tag: String   = defaultTag,
         requestLevel  : NetworkLoggingLevel = .full,
         responseLevel : NetworkLoggingLevel = .full,
         expectedType  : String? = "application/json") {
        self.tag = tag
        self.expectedType  = expectedType
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
                messages.append("--- Body: Unhandled Content Type (\(String(describing: contentType))")
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
            request.allHTTPHeaderFields?.forEach {
                messages.append("--- Header: \($0.key): \($0.value)")
            }
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
            response.allHeaderFields.forEach {
                messages.append("--- Header: \($0.key): \($0.value)")
            }
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
        createMessage(from: messages).forEach { print($0) }
        print()
    }
    
}


public extension NetworkLogger where Self == DefaultLogger {
    
    static func `default`(requestLevel: NetworkLoggingLevel  = .full,
                          responseLevel: NetworkLoggingLevel = .full) -> NetworkLogger {
        DefaultLogger(requestLevel: requestLevel, responseLevel: responseLevel)
    }
    
    static func `default`(logLevel: NetworkLoggingLevel = .full) -> NetworkLogger {
        `default`(requestLevel: logLevel, responseLevel: logLevel)
    }
    
    static var `default`: NetworkLogger { `default`(logLevel: .full) }
    
}



//
//  LoggerProtocol.swift
//  
//
//  Created by Nikolas Konstantakopoulos on 14/2/22.
//

import Foundation
import OSLog
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

public protocol LogStream: Sendable {
    func log(_ message: String)
    func log(_ message: String, for type: LogType)
}

public enum LogType: Sendable {
    case info
    case warning
    case critical
}


public protocol NetworkLogger: AnyObject, Sendable {
    var tag           : String { get }
    var requestLevel  : NetworkLoggingLevel { get }
    var responseLevel : NetworkLoggingLevel { get }
    
    func log(_ message  :  String,  for: NetworkLoggingType, type: LogType)
    func log(_ messages : [String], for: NetworkLoggingType, type: LogType)
    func log(request    : URLRequest, type: LogType)
    func log(response   : HTTPURLResponse, with: Data?, type: LogType)
}

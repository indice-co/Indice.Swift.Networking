//
//  NetworkClient_RequestLogger.swift
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

public protocol NetworkClient_RequestLogger {
    var tag   : String { get set }
    var requestLevel  : NetworkLoggingLevel { get set }
    var responseLevel : NetworkLoggingLevel { get set }
    
    func log(_ message  :  String,  for: NetworkLoggingType)
    func log(_ messages : [String], for: NetworkLoggingType)
    func log(request  : URLRequest)
    func log(response : HTTPURLResponse, with: Data?)
}
